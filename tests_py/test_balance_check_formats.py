from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from validate_balance import ValidationResult, validate_skill_checks


def test_real_check_formats_require_both_outcomes_without_false_legacy_warning():
    for outcomes in [{"success": "passed", "failure": "failed"}, {"on_success": "passed", "on_failure": "failed"}]:
        for node in [{"skill_check": {"skill": "empathy", "dc": 12, **outcomes}},
                     {"type": "skill_check", "check": {"skill": "empathy", "dc": 12, **outcomes}}]:
            result = ValidationResult()
            validate_skill_checks({"fixture": {"data": {"nodes": {"check": node}}}}, result)
            assert not result.failures
            assert not result.warnings
    result = ValidationResult()
    validate_skill_checks({"fixture": {"data": {"nodes": {"check": {"skill_check": {"skill": "empathy", "dc": 12, "success": "passed"}}}}}}, result)
    assert any("missing success/failure" in warning for warning in result.warnings)


def test_modern_threshold_only_check_and_node_outcomes_keep_native_contract():
    node = {"type": "skill_check", "check": {"stat": "empathy", "threshold": 3},
            "on_success": "passed", "on_failure": "failed"}
    result = ValidationResult()
    validate_skill_checks({"fixture": {"data": {"nodes": {"check": node}}}}, result)
    assert not result.failures and not result.warnings
    assert node["check"] == {"stat": "empathy", "threshold": 3}, "Lint must not mutate authored metadata"
    for invalid in [{"stat": "empathy"}, {"stat": "empathy", "threshold": 0},
                    {"stat": "empathy", "threshold": 21}, {"stat": "empathy", "threshold": "3"}]:
        result = ValidationResult()
        validate_skill_checks({"fixture": {"data": {"nodes": {"check": {**node, "check": invalid}}}}}, result)
        assert result.failures
