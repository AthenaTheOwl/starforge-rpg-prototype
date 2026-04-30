import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_godot_project_shape() -> None:
    assert (ROOT / "project.godot").exists()
    assert (ROOT / "scenes" / "menus" / "title_screen.tscn").exists()
    assert len(list((ROOT / "data").rglob("*.json"))) >= 80
    assert len(list((ROOT / "scripts").rglob("*.gd"))) >= 40
    assert len(list((ROOT / "tests").rglob("*.gd"))) >= 10


def test_static_project_validation() -> None:
    result = subprocess.run(
        [sys.executable, "tools/validate_project.py"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )

    assert result.returncode == 0, result.stdout
