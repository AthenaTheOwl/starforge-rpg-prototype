#!/usr/bin/env python3
"""Run deterministic release gates for the Godot RPG prototype repo."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GENERATED_DIRS = [ROOT / ".godot"]


def run(label: str, command: list[str]) -> int:
    print(f"\n== {label} ==")
    print("+ " + " ".join(command))
    environment = os.environ.copy()
    if label.startswith("Godot"):
        state = ROOT / "reports" / "native-state"
        for key in ["APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"]:
            directory = state / key.lower()
            directory.mkdir(parents=True, exist_ok=True)
            environment[key] = str(directory)
        environment["STARFORGE_TEST_STATE_ROOT"] = str(state)
    try:
        result = subprocess.run(command, cwd=ROOT, check=False, text=True, encoding="utf-8", errors="replace",
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180, env=environment)
    except subprocess.TimeoutExpired as exc:
        if exc.stdout:
            print(exc.stdout.decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else exc.stdout)
        print(f"{label} timed out after 180 seconds")
        return 1
    print(result.stdout, end="")
    # GUT 9.3 can ignore scripts that fail to compile, and can label a runtime
    # error as a zero-assertion Risky test without failing the process itself.
    if label.startswith("Godot") and re.search(r"SCRIPT ERROR:|\[Risky\]|Ignoring script .*because", result.stdout):
        print("native gate rejected a script error, ignored script or risky test")
        return 1
    return result.returncode


def verify_gut_report(path: Path) -> int:
    """Require every checked-in test method to execute with a real assertion."""
    expected = {
        (source.relative_to(ROOT).as_posix(), name)
        for source in (ROOT / "tests").rglob("test_*.gd")
        for name in re.findall(r"^func (test_\w+)\(", source.read_text(encoding="utf-8"), re.MULTILINE)
    }
    try:
        document = ET.parse(path).getroot()
        cases = document.findall(".//testcase")
        actual = {(case.get("classname"), case.get("name")) for case in cases}
        bad = [case for case in cases if case.get("status") != "pass"
               or int(case.get("assertions", "0")) < 1
               or any(case.find(tag) is not None for tag in ["failure", "error", "skipped"])]
        if not expected or actual != expected or bad or len(cases) != len(actual):
            print(f"GUT report rejected: missing={sorted(expected - actual)}, unexpected={sorted(actual - expected)}, nonpassing={len(bad)}")
            return 1
    except (OSError, ET.ParseError, ValueError) as exc:
        print(f"GUT report missing or invalid: {exc}")
        return 1
    print(f"GUT report verified: {len(cases)} asserted tests, no skipped or missing methods")
    return 0


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
        gut_report.unlink(missing_ok=True)
        # A clean checkout has no global class/resource cache. Register it before
        # loading GUT, rather than relying on a previous interactive editor run.
        imported = run("Godot import", [godot, "--headless", "--editor", "--path", str(ROOT), "--import", "--quit"])
        failures += 1 if imported else 0
        preflight = 1 if imported else run("Godot state preflight", [godot, "--headless", "--path", str(ROOT),
            "-s", "tools/native_state_preflight.gd"])
        failures += 1 if not imported and preflight else 0
        compiled = 1 if preflight else run("Godot project script compilation", [godot, "--headless", "--path", str(ROOT),
            "-s", "tools/compile_scripts.gd"])
        failures += 1 if not preflight and compiled else 0
        failures += 1 if not compiled and run(
            "Godot GUT",
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "-s",
                "addons/gut/gut_cmdln.gd",
                "-gexit",
                "-gdisable_colors",
                f"-gjunit_xml_file={gut_report}",
            ],
        ) else 0
        if not compiled:
            failures += verify_gut_report(gut_report)
        if not compiled:
            failures += 1 if run("Godot runtime smoke", [godot, "--headless", "--path", str(ROOT),
                "-s", "tools/runtime_smoke.gd"]) else 0
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
