// screen-video's tool for macOS app flows: it opens an app, reads the parts of its window through
// the Accessibility API, presses and types with posted events, and pictures and records one window
// with ScreenCaptureKit. `setup mac` builds it into the data folder:
//
//   swiftc -O -parse-as-library -o <data>/apps/mac/screen-video-mac screen-video-mac.swift
//
// It needs macOS 14 or later, and two permissions for the app the agent runs in (such as Terminal):
// Screen Recording, to picture and record the window, and Accessibility, to read and press its parts.
//
// | Command | What it prints |
// |---|---|
// | `permissions` | `{"screenRecording": bool, "accessibility": bool}` |
// | `open-settings screen-recording\|accessibility` | nothing; opens that page of System Settings |
// | `launch <bundle id>` | `{"pid": n, "window": {"id", "x", "y", "width", "height", "scale"}}` once the app's window shows (points of the screen) |
// | `activate <bundle id>` | nothing; brings the app to the front |
// | `parts <pid>` | the parts of the app's main window: `role`, `subrole`, `title`, `description`, `value`, `identifier`, `enabled`, and `frame` (`[x, y, width, height]` in points of the window) |
// | `press <window id> <x> <y>` | nothing; presses the point (points of the window) |
// | `type <text>` | nothing; types the text a character at a time, 0.11 seconds apart |
// | `key <name>` | nothing; presses a key such as `Enter` or `Meta+A` |
// | `screenshot <window id> <file>` | nothing; saves a PNG of the window |
// | `record <window id> <file>` | `{"started": ms}` when the first frame arrives (milliseconds since 1970); records the window into an mp4 until SIGINT or SIGTERM |
//
// Only the one window is ever captured: the filter is the window itself, independent of the
// display, so other windows, the desktop, and notifications never reach a picture or a recording.

import AppKit
import ApplicationServices
import AVFoundation
import CoreMedia
import ScreenCaptureKit
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("screen-video-mac: \(message)\n".utf8))
  exit(1)
}

func printJSON(_ value: Any) {
  guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else { fail("could not write JSON") }
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data("\n".utf8))
}

func number(_ text: String, _ what: String) -> Double {
  guard let value = Double(text) else { fail("\(what) must be a number, not \(text)") }
  return value
}

func windowID(_ text: String) -> CGWindowID {
  guard let value = UInt32(text) else { fail("the window id must be a whole number, not \(text)") }
  return CGWindowID(value)
}

// MARK: - Windows

/// The window server's record of a window, or nil when it is gone.
func windowInfo(_ id: CGWindowID) -> [String: Any]? {
  let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]]
  return list?.first { ($0[kCGWindowNumber as String] as? Int).map(CGWindowID.init) == id }
}

func boundsOf(_ info: [String: Any]) -> CGRect {
  guard let dictionary = info[kCGWindowBounds as String] as! CFDictionary?, let rect = CGRect(dictionaryRepresentation: dictionary) else { return .zero }
  return rect
}

/// The pixels per point of the screen a rectangle (top-left origin) is mostly on.
func scaleAt(_ rect: CGRect) -> Double {
  let top = NSScreen.screens.first?.frame.height ?? 0
  let flipped = CGRect(x: rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height)
  let screen = NSScreen.screens.max { a, b in
    let x = a.frame.intersection(flipped)
    let y = b.frame.intersection(flipped)
    return x.width * x.height < y.width * y.height
  }
  return Double(screen?.backingScaleFactor ?? 2)
}

/// The app's main window as the window server knows it: the one at the Accessibility API's main
/// window, or else its largest normal window.
func mainWindow(of pid: pid_t) -> (id: CGWindowID, bounds: CGRect)? {
  let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
  let owned = list.filter { ($0[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
    .compactMap { info -> (id: CGWindowID, bounds: CGRect)? in
      guard let id = info[kCGWindowNumber as String] as? Int else { return nil }
      return (CGWindowID(id), boundsOf(info))
    }
    .filter { $0.bounds.width > 40 && $0.bounds.height > 40 }
  if let frame = axMainWindow(of: pid).flatMap(frameOf), let same = owned.first(where: { abs($0.bounds.minX - frame.minX) < 3 && abs($0.bounds.minY - frame.minY) < 3 && abs($0.bounds.width - frame.width) < 3 }) {
    return same
  }
  return owned.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
}

func bringToFront(pid: pid_t) {
  NSRunningApplication(processIdentifier: pid)?.activate()
}

// MARK: - Accessibility

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
  var value: AnyObject?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func text(_ element: AXUIElement, _ name: String) -> String? {
  attribute(element, name) as? String
}

func frameOf(_ element: AXUIElement) -> CGRect? {
  guard let position = attribute(element, kAXPositionAttribute), let size = attribute(element, kAXSizeAttribute),
        CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
  var point = CGPoint.zero
  var extent = CGSize.zero
  AXValueGetValue(position as! AXValue, .cgPoint, &point)
  AXValueGetValue(size as! AXValue, .cgSize, &extent)
  return CGRect(origin: point, size: extent)
}

func axMainWindow(of pid: pid_t) -> AXUIElement? {
  let app = AXUIElementCreateApplication(pid)
  AXUIElementSetMessagingTimeout(app, 3)
  for name in [kAXMainWindowAttribute, kAXFocusedWindowAttribute] {
    if let window = attribute(app, name), CFGetTypeID(window) == AXUIElementGetTypeID() { return (window as! AXUIElement) }
  }
  return (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first
}

/// The parts of the app's main window, in reading order, with frames in points of the window.
func parts(of pid: pid_t) -> [[String: Any]] {
  guard let window = axMainWindow(of: pid), let origin = frameOf(window)?.origin else { fail("the app \(pid) has no window to read") }
  var found: [[String: Any]] = []
  func walk(_ element: AXUIElement, depth: Int) {
    if found.count >= 4000 || depth > 60 { return }
    if element != window, let frame = frameOf(element) {
      let value: Any
      switch attribute(element, kAXValueAttribute) {
      case let string as String: value = string
      case let number as NSNumber: value = number.stringValue
      default: value = NSNull()
      }
      let nothing: Any = NSNull()
      let edges: [CGFloat] = [frame.minX - origin.x, frame.minY - origin.y, frame.width, frame.height]
      var part: [String: Any] = [:]
      part["role"] = text(element, kAXRoleAttribute) ?? "AXUnknown"
      part["subrole"] = text(element, kAXSubroleAttribute) ?? nothing
      part["title"] = text(element, kAXTitleAttribute) ?? nothing
      part["description"] = text(element, kAXDescriptionAttribute) ?? nothing
      part["value"] = value
      part["identifier"] = text(element, "AXIdentifier") ?? nothing
      part["enabled"] = (attribute(element, kAXEnabledAttribute) as? Bool) ?? true
      part["frame"] = edges.map { Double(($0 * 10).rounded() / 10) }
      found.append(part)
    }
    for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { walk(child, depth: depth + 1) }
  }
  walk(window, depth: 0)
  return found
}

// MARK: - Input

let events = CGEventSource(stateID: .hidSystemState)

func press(window id: CGWindowID, x: Double, y: Double) {
  guard let info = windowInfo(id) else { fail("the window \(id) is gone") }
  if let owner = info[kCGWindowOwnerPID as String] as? Int { bringToFront(pid: pid_t(owner)) }
  let bounds = boundsOf(info)
  let point = CGPoint(x: bounds.minX + x, y: bounds.minY + y)
  for (type, pause) in [(CGEventType.mouseMoved, 60_000), (.leftMouseDown, 70_000), (.leftMouseUp, 30_000)] {
    CGEvent(mouseEventSource: events, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(useconds_t(pause))
  }
}

func type(_ value: String) {
  for character in value {
    let units = Array(String(character).utf16)
    for down in [true, false] {
      let event = CGEvent(keyboardEventSource: events, virtualKey: 0, keyDown: down)
      event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
      event?.post(tap: .cghidEventTap)
    }
    usleep(110_000)
  }
}

let KEYS: [String: CGKeyCode] = [
  "Enter": 36, "Tab": 48, "Space": 49, "Backspace": 51, "Escape": 53, "Delete": 117,
  "Home": 115, "End": 119, "PageUp": 116, "PageDown": 121,
  "ArrowLeft": 123, "ArrowRight": 124, "ArrowDown": 125, "ArrowUp": 126,
  "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9, "B": 11, "Q": 12, "W": 13, "E": 14,
  "R": 15, "Y": 16, "T": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
  "O": 31, "U": 32, "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46,
]
let MODIFIERS: [String: CGEventFlags] = ["Meta": .maskCommand, "Control": .maskControl, "Alt": .maskAlternate, "Shift": .maskShift]

func key(_ name: String) {
  let words = name.split(separator: "+").map(String.init)
  guard let last = words.last, let code = KEYS[last.count == 1 ? last.uppercased() : last] else { fail("no key named \(name)") }
  var flags = CGEventFlags()
  for word in words.dropLast() {
    guard let flag = MODIFIERS[word] else { fail("no modifier named \(word) (use Meta, Control, Alt, or Shift)") }
    flags.insert(flag)
  }
  for down in [true, false] {
    let event = CGEvent(keyboardEventSource: events, virtualKey: code, keyDown: down)
    event?.flags = flags
    event?.post(tap: .cghidEventTap)
    usleep(40_000)
  }
}

// MARK: - Pictures and recordings

/// A filter of the one window, independent of the display it is on, and the size to capture it at.
func windowFilter(_ id: CGWindowID) async -> (filter: SCContentFilter, width: Int, height: Int) {
  let content: SCShareableContent
  do {
    content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
  } catch {
    fail("cannot list the windows (is Screen Recording on for this app?): \(error.localizedDescription)")
  }
  guard let window = content.windows.first(where: { $0.windowID == id }) else { fail("the window \(id) is gone") }
  let filter = SCContentFilter(desktopIndependentWindow: window)
  let scale = Double(filter.pointPixelScale)
  // Even sizes, as the H.264 encoder needs
  let even = { (points: CGFloat) in max(2, Int((Double(points) * scale / 2).rounded()) * 2) }
  return (filter, even(window.frame.width), even(window.frame.height))
}

func configuration(width: Int, height: Int) -> SCStreamConfiguration {
  let config = SCStreamConfiguration()
  config.width = width
  config.height = height
  config.showsCursor = false
  config.ignoreShadowsSingleWindow = true
  config.pixelFormat = kCVPixelFormatType_32BGRA
  return config
}

func screenshot(window id: CGWindowID, file: String) async {
  let (filter, width, height) = await windowFilter(id)
  let image: CGImage
  do {
    image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration(width: width, height: height))
  } catch {
    fail("cannot picture the window \(id): \(error.localizedDescription)")
  }
  guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: file) as CFURL, UTType.png.identifier as CFString, 1, nil) else { fail("cannot write \(file)") }
  CGImageDestinationAddImage(destination, image, nil)
  if !CGImageDestinationFinalize(destination) { fail("cannot write \(file)") }
}

/// Writes the frames of a stream into an mp4, from the first complete frame.
final class Recording: NSObject, SCStreamOutput, SCStreamDelegate {
  let writer: AVAssetWriter
  let input: AVAssetWriterInput
  let frames = DispatchQueue(label: "screen-video-mac.frames")
  var began = false
  var last: CMSampleBuffer?

  init(file: String, width: Int, height: Int) throws {
    try? FileManager.default.removeItem(atPath: file)
    writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: file), fileType: .mp4)
    input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000, AVVideoExpectedSourceFrameRateKey: 30],
    ])
    input.expectsMediaDataInRealTime = true
    writer.add(input)
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen, buffer.isValid,
          let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
          let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete else { return }
    let time = buffer.presentationTimeStamp
    if !began {
      began = true
      writer.startWriting()
      writer.startSession(atSourceTime: time)
      // The frame's moment, in milliseconds since 1970: now, less how long ago the frame was taken
      let age = CMClockGetTime(CMClockGetHostTimeClock()).seconds - time.seconds
      printJSON(["started": ((Date().timeIntervalSince1970 - max(0, age)) * 1000).rounded()])
    }
    if input.isReadyForMoreMediaData, input.append(buffer) { last = buffer }
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    fail("the recording stopped: \(error.localizedDescription)")
  }

  /// Ends the file at `end`, holding the last frame until then, since a still window sends no frames.
  func finish(at end: CMTime) async {
    let held: Bool = frames.sync {
      guard began, let last else { return false }
      var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: end, decodeTimeStamp: .invalid)
      var copy: CMSampleBuffer?
      if end > last.presentationTimeStamp, CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: last, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &copy) == noErr, let copy, input.isReadyForMoreMediaData {
        input.append(copy)
      }
      return true
    }
    if !held { fail("the recording has no frames") }
    input.markAsFinished()
    writer.endSession(atSourceTime: end)
    await writer.finishWriting()
    if writer.status != .completed { fail("cannot write the recording: \(writer.error?.localizedDescription ?? "unknown")") }
  }
}

/// Waits for SIGINT or SIGTERM.
func untilStopped() async {
  signal(SIGINT, SIG_IGN)
  signal(SIGTERM, SIG_IGN)
  let queue = DispatchQueue(label: "screen-video-mac.signals")
  await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
    var waiting = true
    let sources = [SIGINT, SIGTERM].map { DispatchSource.makeSignalSource(signal: $0, queue: queue) }
    for source in sources {
      source.setEventHandler {
        guard waiting else { return }
        waiting = false
        sources.forEach { $0.cancel() }
        done.resume()
      }
      source.resume()
    }
  }
}

func record(window id: CGWindowID, file: String) async {
  let (filter, width, height) = await windowFilter(id)
  let config = configuration(width: width, height: height)
  config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
  config.queueDepth = 6
  let recording: Recording
  do {
    recording = try Recording(file: file, width: width, height: height)
  } catch {
    fail("cannot write \(file): \(error.localizedDescription)")
  }
  let stream = SCStream(filter: filter, configuration: config, delegate: recording)
  do {
    try stream.addStreamOutput(recording, type: .screen, sampleHandlerQueue: recording.frames)
    try await stream.startCapture()
  } catch {
    fail("cannot record the window \(id) (is Screen Recording on for this app?): \(error.localizedDescription)")
  }
  await untilStopped()
  let end = CMClockGetTime(CMClockGetHostTimeClock())
  try? await stream.stopCapture()
  await recording.finish(at: end)
}

// MARK: - Apps and settings

func launch(_ bundle: String) async {
  guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { fail("no app with the bundle id \(bundle)") }
  let options = NSWorkspace.OpenConfiguration()
  options.activates = true
  let app: NSRunningApplication
  do {
    app = try await NSWorkspace.shared.openApplication(at: url, configuration: options)
  } catch {
    fail("cannot open \(bundle): \(error.localizedDescription)")
  }
  let pid = app.processIdentifier
  for _ in 0..<240 {
    if let window = mainWindow(of: pid) {
      bringToFront(pid: pid)
      let b = window.bounds
      printJSON(["pid": Int(pid), "window": ["id": Int(window.id), "x": b.minX, "y": b.minY, "width": b.width, "height": b.height, "scale": scaleAt(b)]])
      return
    }
    try? await Task.sleep(nanoseconds: 250_000_000)
  }
  fail("\(bundle) opened no window within 60 seconds")
}

func activate(_ bundle: String) {
  guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else { fail("\(bundle) is not running") }
  app.activate()
}

let SETTINGS = [
  "screen-recording": "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
  "accessibility": "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
]

func openSettings(_ page: String) {
  guard let address = SETTINGS[page], let url = URL(string: address) else { fail("no settings page \(page) (use screen-recording or accessibility)") }
  // Asking once puts this app in the page's list, so the user only turns it on
  if page == "screen-recording" { _ = CGRequestScreenCaptureAccess() }
  if page == "accessibility" { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) }
  NSWorkspace.shared.open(url)
}

// MARK: - Commands

@main
struct ScreenVideoMac {
  static func main() async {
    // ScreenCaptureKit needs this process's connection to the window server, which the shared
    // application opens; the policy keeps it out of the Dock and the app switcher
    NSApplication.shared.setActivationPolicy(.prohibited)
    let args = Array(CommandLine.arguments.dropFirst())
    let need = { (count: Int, usage: String) in
      if args.count != count + 1 { fail("usage: screen-video-mac \(usage)") }
    }
    switch args.first {
    case "permissions":
      printJSON(["screenRecording": CGPreflightScreenCaptureAccess(), "accessibility": AXIsProcessTrusted()])
    case "open-settings":
      need(1, "open-settings screen-recording|accessibility")
      openSettings(args[1])
    case "launch":
      need(1, "launch <bundle id>")
      await launch(args[1])
    case "activate":
      need(1, "activate <bundle id>")
      activate(args[1])
    case "parts":
      need(1, "parts <pid>")
      guard let pid = pid_t(args[1]) else { fail("the pid must be a whole number") }
      printJSON(parts(of: pid))
    case "press":
      need(3, "press <window id> <x> <y>")
      press(window: windowID(args[1]), x: number(args[2], "x"), y: number(args[3], "y"))
    case "type":
      need(1, "type <text>")
      type(args[1])
    case "key":
      need(1, "key <name>")
      key(args[1])
    case "screenshot":
      need(2, "screenshot <window id> <file>")
      await screenshot(window: windowID(args[1]), file: args[2])
    case "record":
      need(2, "record <window id> <file>")
      await record(window: windowID(args[1]), file: args[2])
    default:
      fail("usage: screen-video-mac permissions | open-settings <page> | launch <bundle id> | activate <bundle id> | parts <pid> | press <window id> <x> <y> | type <text> | key <name> | screenshot <window id> <file> | record <window id> <file>")
    }
  }
}
