#!/usr/bin/env python3
"""Reject label/connector collisions in a diagram geometry manifest."""

import json
import sys
from pathlib import Path


CLEARANCE = 12


def rect_hits_connector(label, connector):
    """Return whether a connector segment intersects the label's clearance box."""
    bounds = (
        (label["x"] - CLEARANCE, label["x"] + label["width"] + CLEARANCE),
        (label["y"] - CLEARANCE, label["y"] + label["height"] + CLEARANCE),
    )
    starts = (connector["x1"], connector["y1"])
    deltas = (connector["x2"] - connector["x1"], connector["y2"] - connector["y1"])
    enter, leave = 0.0, 1.0
    for start, delta, (lower, upper) in zip(starts, deltas, bounds):
        if delta == 0:
            if not lower <= start <= upper:
                return False
            continue
        first, second = (lower - start) / delta, (upper - start) / delta
        if first > second:
            first, second = second, first
        enter, leave = max(enter, first), min(leave, second)
        if enter > leave:
            return False
    return True


def inside_with_padding(element, container):
    padding = container.get("padding", 0)
    return (
        element["x"] >= container["x"] + padding
        and element["y"] >= container["y"] + padding
        and element["x"] + element["width"] <= container["x"] + container["width"] - padding
        and element["y"] + element["height"] <= container["y"] + container["height"] - padding
    )


def validate_diagram(manifest):
    errors = []
    if not manifest.get("theme"):
        errors.append("diagram has no theme")
    if not manifest.get("metaphor"):
        errors.append("diagram has no visual metaphor")
    containers = {container["id"]: container for container in manifest.get("containers", [])}
    for element in manifest.get("elements", []):
        container_id = element.get("container")
        if container_id not in containers:
            errors.append(f"element {element.get('id', '?')} has no known container")
        elif not inside_with_padding(element, containers[container_id]):
            errors.append(f"element {element.get('id', '?')} violates container {container_id} padding")
    for connector in manifest.get("connectors", []):
        if not connector.get("lane"):
            errors.append(f"connector {connector.get('id', '?')} has no semantic lane")
    for label in manifest.get("labels", []):
        for connector in manifest.get("connectors", []):
            if rect_hits_connector(label, connector):
                errors.append(f"label {label.get('id', '?')} collides with connector {connector.get('id', '?')}")
    return errors


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: validate_diagram_geometry.py manifest.json")
    manifest = json.loads(Path(sys.argv[1]).read_text())
    diagrams = manifest.get("diagrams", [manifest])
    errors = []
    for index, diagram in enumerate(diagrams, 1):
        errors.extend(f"slide {index}: {error}" for error in validate_diagram(diagram))
    if errors:
        raise SystemExit("Diagram geometry rejected:\n- " + "\n- ".join(errors))
    print("OK: diagram geometry has semantic lanes and clear labels")


if __name__ == "__main__":
    main()
