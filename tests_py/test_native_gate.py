from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import check_release


def test_native_gate_imports_clean_project_before_gut_without_debugger(monkeypatch, tmp_path) -> None:
    calls = []
    monkeypatch.setattr(check_release, "ROOT", tmp_path)
    monkeypatch.setattr(check_release, "GENERATED_DIRS", [tmp_path / ".godot"])
    monkeypatch.setattr(sys, "argv", ["check_release.py", "--clean", "--require-godot", "--godot", "portable-godot"])
    monkeypatch.setattr(check_release, "verify_gut_report", lambda path: 0)
    def fake_run(label, command):
        calls.append((label, command))
        return 0
    monkeypatch.setattr(check_release, "run", fake_run)
    assert check_release.main() == 0
    labels = [label for label, _ in calls]
    assert labels.index("Godot import") < labels.index("Godot GUT")
    assert labels.index("Godot import") < labels.index("Godot state preflight") < labels.index("Godot GUT")
    assert labels.index("Godot state preflight") < labels.index("Godot project script compilation") < labels.index("Godot GUT")
    gut = dict(calls)["Godot GUT"]
    assert "-d" not in gut
    assert "--import" in dict(calls)["Godot import"]


def test_failed_actual_user_directory_preflight_blocks_gut_and_smoke(monkeypatch, tmp_path) -> None:
    calls = []
    monkeypatch.setattr(check_release, "ROOT", tmp_path)
    monkeypatch.setattr(check_release, "GENERATED_DIRS", [tmp_path / ".godot"])
    monkeypatch.setattr(sys, "argv", ["check_release.py", "--godot", "portable-godot"])
    def fake_run(label, command):
        calls.append(label)
        return 1 if label == "Godot state preflight" else 0
    monkeypatch.setattr(check_release, "run", fake_run)
    assert check_release.main() == 1
    assert "Godot GUT" not in calls
    assert "Godot runtime smoke" not in calls


def test_unused_project_script_compile_failure_blocks_play_and_save_tests(monkeypatch, tmp_path) -> None:
    calls = []
    monkeypatch.setattr(check_release, "ROOT", tmp_path)
    monkeypatch.setattr(check_release, "GENERATED_DIRS", [tmp_path / ".godot"])
    monkeypatch.setattr(sys, "argv", ["check_release.py", "--godot", "portable-godot"])
    def fake_run(label, command):
        calls.append(label)
        return 1 if label == "Godot project script compilation" else 0
    monkeypatch.setattr(check_release, "run", fake_run)
    assert check_release.main() == 1
    assert "Godot GUT" not in calls
    assert "Godot runtime smoke" not in calls


def test_native_gate_fails_on_script_error_even_when_engine_exits_zero(monkeypatch) -> None:
    monkeypatch.setattr(check_release.subprocess, "run", lambda *args, **kwargs:
        SimpleNamespace(returncode=0, stdout="SCRIPT ERROR: fixture failed\n"))
    assert check_release.run("Godot GUT", ["portable-godot"]) == 1


def test_native_gate_fails_on_ignored_test_script_or_risky_test(monkeypatch) -> None:
    for output in ["Ignoring script res://test.gd because it does not extend GutTest", "[Risky]: Did not assert"]:
        monkeypatch.setattr(check_release.subprocess, "run", lambda *args, **kwargs:
            SimpleNamespace(returncode=0, stdout=output))
        assert check_release.run("Godot GUT", ["portable-godot"]) == 1


def test_native_report_requires_every_method_and_assertion(monkeypatch, tmp_path) -> None:
    source = tmp_path / "tests/unit/test_fixture.gd"
    source.parent.mkdir(parents=True)
    source.write_text("extends GutTest\nfunc test_first():\n pass\nfunc test_second():\n pass\n")
    monkeypatch.setattr(check_release, "ROOT", tmp_path)
    report = tmp_path / "gut.xml"
    assert check_release.verify_gut_report(report) == 1
    first = '<testcase classname="tests/unit/test_fixture.gd" name="test_first" status="pass" assertions="1" />'
    second = first.replace("test_first", "test_second")
    report.write_text(f"<testsuites>{first}</testsuites>")
    assert check_release.verify_gut_report(report) == 1, "An ignored source method cannot produce a green gate"
    for invalid in [second.replace('assertions="1"', 'assertions="0"'), second.replace('status="pass"', 'status="pending"')]:
        report.write_text(f"<testsuites>{first}{invalid}</testsuites>")
        assert check_release.verify_gut_report(report) == 1
    report.write_text(f"<testsuites>{first}{second}</testsuites>")
    assert check_release.verify_gut_report(report) == 0
