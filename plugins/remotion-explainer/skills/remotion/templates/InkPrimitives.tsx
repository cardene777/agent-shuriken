// Ink primitives for the hand-drawn narrative pattern (formats/hand-drawn-narrative.md).
// They draw ink lines, double lines, and paths in order, and nothing else: no setting, person,
// object, or prop. Drive `progress` from useCurrentFrame() so every frame renders the same way.
import type React from "react";

// Maps the progress of a whole drawing (0 to 1) to the progress of one path that starts at `delay`,
// clamped to 0..1, so paths drawn later wait for the ones before them.
export const handDrawProgress = (progress: number, delay = 0) =>
  Math.max(0, Math.min(1, (progress - delay) / Math.max(0.001, 1 - delay)));

// One ink stroke that draws itself along its path. pathLength={1} normalizes the dash, so the stroke
// is fully hidden at 0 and fully drawn at 1 whatever the length of the path. A filled path also fades
// in with the stroke, so its fill never shows before its outline.
export const InkPath: React.FC<{
  d: string;
  progress: number;
  delay?: number;
  color?: string;
  width?: number;
  fill?: string;
  opacity?: number;
}> = ({d, progress, delay = 0, color = "#172d3b", width = 6, fill = "none", opacity = 1}) => {
  const draw = handDrawProgress(progress, delay);
  return (
    <path
      d={d}
      fill={fill}
      stroke={color}
      strokeWidth={width}
      strokeLinecap="round"
      strokeLinejoin="round"
      pathLength={1}
      strokeDasharray="1"
      strokeDashoffset={1 - draw}
      opacity={opacity * (fill === "none" ? 1 : draw)}
    />
  );
};

// A double line: a wider paper-colored stroke under the ink stroke, so the line stays legible where
// it crosses other lines.
export const InkDoublePath: React.FC<{
  d: string;
  progress: number;
  delay?: number;
  color?: string;
  width?: number;
}> = ({d, progress, delay = 0, color = "#172d3b", width = 7}) => (
  <>
    <InkPath d={d} progress={progress} delay={delay} color="#fffdf8" width={width + 3} opacity={0.95} />
    <InkPath d={d} progress={progress} delay={delay} color={color} width={width} />
  </>
);
