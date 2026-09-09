from collections import Counter

from app.evaluation.agronomy_cases import EVALUATION_CASES


def test_offline_evaluation_has_fifty_cases_per_initial_crop_and_required_edges():
    counts = Counter(case["crop"] for case in EVALUATION_CASES)
    assert counts == {"wheat": 50, "rice": 50, "sugarcane": 50}
    scenarios = {case["scenario"] for case in EVALUATION_CASES}
    assert {"missing_crop_stage", "stale_satellite", "conflicting_sensor_weather", "sensor_free", "image_ambiguous"} <= scenarios
    assert all(case["requires_agronomist_review"] for case in EVALUATION_CASES)
