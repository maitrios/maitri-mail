#!/usr/bin/env python3
"""The plugin was written against upstream's shell; this checks it only reaches
for qs.Ui / qs.Commons APIs that maitri's shell actually provides.

Point MAITRI_SHELL_DIR at a maitri checkout's shell/ directory (CI checks out
maitrios/maitri). Without it the check is skipped, so `make test` still runs on
machines without maitri sources.

Two surfaces are compared:
- the qs.Ui stubs under ui/tests/qml/imports, which upstream keeps in step with
  what the plugin uses: every stub type, property, signal and function must
  exist in maitri's component (or a maitri base component it extends);
- every Style.*, Color.* and Border.* member the plugin's QML and JS read.
"""
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
STUBS = ROOT / "ui/tests/qml/imports/qs/Ui"

# Members a maitri component inherits from the Qt Quick type at its root.
QT_INHERITED = {
    "Text": {"text", "color", "font", "leftPadding", "rightPadding", "topPadding", "bottomPadding"},
    "ToolTip": {"text", "visible", "delay", "timeout"},
    "TextField": {"text", "placeholderText", "readOnly", "echoMode", "accepted", "textEdited", "font"},
    "Rectangle": {"color", "radius", "border"},
    "Item": set(),
    "Column": set(),
    "Row": set(),
    "PanelWindow": set(),
}

MEMBER = re.compile(r"^\s*(?:readonly\s+|required\s+|default\s+)*(?:property\s+[\w.<>]+\s+(\w+)|signal\s+(\w+)|function\s+(\w+))", re.M)


def members(path):
    found = set()
    for match in MEMBER.finditer(path.read_text()):
        found.add(next(group for group in match.groups() if group))
    return found


def root_type(path):
    match = re.search(r"^([A-Z][\w.]*)\s*\{", path.read_text(), re.M)
    return match.group(1).split(".")[-1] if match else ""


def provided(shell, name, seen=None):
    seen = seen or set()
    path = shell / "Ui" / f"{name}.qml"
    if name in seen or not path.exists():
        return QT_INHERITED.get(name, set())
    seen.add(name)
    return members(path) | provided(shell, root_type(path), seen)


def ui_types(shell):
    qmldir = (shell / "Ui/qmldir").read_text().splitlines()
    return {line.split()[0] for line in qmldir if line and not line.startswith("module")}


def plugin_sources():
    for path in sorted((ROOT / "ui").rglob("*")):
        if path.suffix in (".qml", ".js") and "tests" not in path.relative_to(ROOT / "ui").parts:
            yield path


def commons_members(shell, singleton):
    return members(shell / "Commons" / f"{singleton}.qml")


def main():
    shell_dir = os.environ.get("MAITRI_SHELL_DIR", "")
    if not shell_dir:
        print("test_maitri_shell_api: MAITRI_SHELL_DIR unset, skipped")
        return 0
    shell = Path(shell_dir)
    problems = []

    available = ui_types(shell)
    for stub in sorted(STUBS.glob("*.qml")):
        name = stub.stem
        if name not in available:
            problems.append(f"qs.Ui.{name} is used by the plugin but maitri's shell has no such type")
            continue
        missing = members(stub) - provided(shell, name)
        for member in sorted(missing):
            problems.append(f"qs.Ui.{name}.{member} is used by the plugin but maitri's {name} lacks it")

    access = re.compile(r"(?<![\w.])(Style|Color|Border)\.(\w+)(?:\.(\w+))?")
    for source in plugin_sources():
        text = re.sub(r"(^|\s)//.*$", r"\1", source.read_text(), flags=re.M)
        for singleton, member, nested in set(access.findall(text)):
            have = commons_members(shell, singleton)
            leaf = nested or member
            if member not in have or (nested and leaf not in have):
                problems.append(f"{source.relative_to(ROOT)} reads {singleton}.{member}"
                                + (f".{nested}" if nested else "") + " which maitri's Commons lacks")

    for problem in sorted(set(problems)):
        print(problem, file=sys.stderr)
    if problems:
        return 1
    print("test_maitri_shell_api: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
