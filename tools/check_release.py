#!/usr/bin/env python3
"""Run deterministic release gates for the Godot RPG prototype repo."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GENERATED_DIRS = [ROOT / ".godot"]


def run(label: str, command: list[str]) -> int:
    print(f"\n== {label} ==")
    print("+ " + " ".join(command))
    return subprocess.run(command, cwd=ROOT, check=False).returncode


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def find_generated_artifacts() -> list[Path]:
    return [path for path in GENERATED_DIRS if path.exists()]


def is_safe_generated_path(path: Path) -> bool:
    resolved = path.resolve()
    return any(resolved == generated.resolve() for generated in GENERATED_DIRS)


def clean_generated_artifacts() -> None:
    for path in find_generated_artifacts():
        if not is_safe_generated_path(path):
            raise RuntimeError(f"refusing to clean path outside known generated roots: {path}")
        if path.exists():
            shutil.rmtree(path)


def verify_no_generated_artifacts() -> int:
    artifacts = find_generated_artifacts()
    if not artifacts:
        return 0

    print("\n== Generated artifact check ==")
    print("release gate found generated Godot editor artifacts:")
    for path in artifacts:
        print(f"- {rel(path)}")
    print("remove them manually or rerun with --clean to remove known Godot churn")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--clean", action="store_true", help="Remove known generated Godot artifacts before and after checks.")
    parser.add_argument("--fail-on-generated", action="store_true", help="Compatibility flag; generated Godot editor artifacts are always release-blocking.")
    parser.add_argument("--godot", help="Path to the Godot 4 executable.")
    parser.add_argument("--require-godot", action="store_true", help="Fail if GUT cannot run.")
    args = parser.parse_args()
    if args.clean:
        clean_generated_artifacts()

    checks = [
        ("Python tests", [sys.executable, "-m", "pytest"]),
        ("Static Godot project validation", [sys.executable, "tools/validate_project.py"]),
        ("Godot playtest path/dead-letter audit", [sys.executable, "tools/playtest_audit.py"]),
        ("Godot balance validation", [sys.executable, "scripts/validate_balance.py"]),
    ]

    failures = verify_no_generated_artifacts()
    for label, command in checks:
        failures += 1 if run(label, command) else 0

    godot = args.godot or os.environ.get("GODOT_EXECUTABLE")
    if godot:
        reports = ROOT / "reports"
        reports.mkdir(exist_ok=True)
        gut_report = reports / "gut-junit.xml"
        failures += 1 if run(
            "Godot GUT",
            [
                godot,
                "--headless",
                "-d",
                "-s",
                "--path",
                str(ROOT),
                "addons/gut/gut_cmdln.gd",
                "-gexit",
                f"-gjunit_xml_file={gut_report}",
            ],
        ) else 0
        if args.clean:
            clean_generated_artifacts()
        failures += verify_no_generated_artifacts()
    elif args.require_godot:
        print("\n== Godot GUT ==")
        print("missing Godot executable; set GODOT_EXECUTABLE or pass --godot")
        failures += 1
    else:
        print("\n== Godot GUT ==")
        print("skipped; set GODOT_EXECUTABLE or pass --godot to include engine tests")

    if failures:
        print(f"\nrelease gate failed: {failures} check(s) failed")
        return 1

    print("\nrelease gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
