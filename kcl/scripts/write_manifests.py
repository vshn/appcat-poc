#!/usr/bin/env python3
"""Render KCL JSON output into individual YAML manifest files."""

import json
import os
import sys


def _format_scalar(value):
    """Return a YAML-safe scalar representation."""
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    return str(value)


def _dump_yaml(value, indent=0):
    """Serialize a Python object to a YAML string (very small subset)."""
    spaces = "  " * indent
    if isinstance(value, dict):
        lines = []
        for key, val in value.items():
            if isinstance(val, (dict, list)):
                lines.append(f"{spaces}{key}:")
                lines.append(_dump_yaml(val, indent + 1))
            else:
                lines.append(f"{spaces}{key}: {_format_scalar(val)}")
        return "\n".join(lines) if lines else f"{spaces}{{}}"
    if isinstance(value, list):
        lines = []
        for item in value:
            if isinstance(item, (dict, list)):
                lines.append(f"{spaces}-")
                lines.append(_dump_yaml(item, indent + 1))
            else:
                lines.append(f"{spaces}- {_format_scalar(item)}")
        return "\n".join(lines) if lines else f"{spaces}[]"
    return f"{spaces}{_format_scalar(value)}"


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: write_manifests.py <section> <output_dir>", file=sys.stderr)
        return 1

    section = sys.argv[1]
    out_dir = sys.argv[2]

    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"Failed to parse JSON from stdin: {exc}", file=sys.stderr)
        return 1

    if section not in data:
        print(f"Section '{section}' not found in KCL output", file=sys.stderr)
        return 1

    files = data[section]
    if not isinstance(files, dict):
        print(f"Section '{section}' must be a mapping", file=sys.stderr)
        return 1

    os.makedirs(out_dir, exist_ok=True)

    for name, content in files.items():
        target = os.path.join(out_dir, name)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        if isinstance(content, str):
            text = content if content.endswith("\n") else content + "\n"
        else:
            text = _dump_yaml(content) + "\n"
        with open(target, "w", encoding="utf-8") as handle:
            handle.write(text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
