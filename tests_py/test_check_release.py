from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import check_release


def test_generated_cleanup_scope_is_only_godot_editor_dir() -> None:
    assert check_release.is_safe_generated_path(ROOT / ".godot") is True
    assert check_release.is_safe_generated_path(ROOT / "project.godot") is False
    assert check_release.is_safe_generated_path(ROOT.parent / "other" / ".godot") is False
