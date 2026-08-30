from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.services.ai_advisor_service import (
    _apply_safety_policy,
    _canonical_category,
    _field_health_payload,
    _guard_chat_response,
    _reconcile_field_health,
    _recommendation_payload,
)


def test_apply_safety_policy_with_empty_advice_returns_none():
    item = {"advice": ""}
    result = _apply_safety_policy(item, [])
    assert result is None


def test_apply_safety_policy_with_string_confidence():
    item = {
        "advice": "Monitor the field for pest symptoms.",
        "confidence": "invalid",
        "category": "Field Monitoring",
        "priority": "low",
        "safety_level": "guarded",
        "requires_expert_confirmation": False,
        "confidence_reason": "Routine observation.",
        "rationale": "Standard check.",
        "evidence_urls": [],
    }
    result = _apply_safety_policy(item, [])
    assert result["confidence"] == 0.4


def test_apply_safety_policy_with_out_of_range_confidence():
    url = "https://agripunjab.gov.pk/guide"
    item = {
        "advice": "Monitor the field for pest symptoms.",
        "confidence": 2.0,
        "category": "Field Monitoring",
        "priority": "low",
        "safety_level": "guarded",
        "requires_expert_confirmation": False,
        "confidence_reason": "Routine observation.",
        "rationale": "Standard check.",
        "evidence_urls": [url],
    }
    approved_evidence = [{"url": url, "approved": True, "excerpt": "Some excerpt"}]
    result = _apply_safety_policy(item, approved_evidence)
    assert result["confidence"] == 1.0


def test_apply_safety_policy_with_invalid_priority():
    item = {
        "advice": "Monitor the field for pest symptoms.",
        "priority": "urgent",
        "confidence": 0.5,
        "category": "Field Monitoring",
        "safety_level": "guarded",
        "requires_expert_confirmation": False,
        "confidence_reason": "Routine observation.",
        "rationale": "Standard check.",
        "evidence_urls": [],
    }
    result = _apply_safety_policy(item, [])
    assert result["priority"] == "medium"


def test_apply_safety_policy_with_unknown_url_filtered_out():
    item = {
        "advice": "Monitor the field for pest symptoms.",
        "evidence_urls": ["https://evil.com/hack"],
        "category": "Field Monitoring",
        "priority": "low",
        "confidence": 0.5,
        "safety_level": "guarded",
        "requires_expert_confirmation": False,
        "confidence_reason": "Routine observation.",
        "rationale": "Standard check.",
    }
    result = _apply_safety_policy(item, [])
    assert result["evidence"] == []


def test_guard_chat_response_with_risky_advice_and_supporting_url():
    text = "Consider using a spray to manage the issue. https://agripunjab.gov.pk/guide"
    approved_evidence = [
        {"url": "https://agripunjab.gov.pk/guide", "approved": True, "excerpt": "Use spray for control"},
    ]
    result = _guard_chat_response(text, approved_evidence, has_images=False)
    assert "Consider using a spray" in result
    assert "agronomist" in result


def test_guard_chat_response_with_existing_visual_disclaimer():
    text = "This is a visual assessment, not a definitive diagnosis. Everything looks fine."
    result = _guard_chat_response(text, [], has_images=True)
    assert result == text


def test_recommendation_payload_with_raw_json_no_code_fence():
    response = SimpleNamespace(
        parsed=None,
        text='{"recommendations": [{"category": "Irrigation", "priority": "high", "advice": "Water now", "rationale": "Soil is dry", "confidence": 0.8, "confidence_reason": "NDVI confirms", "evidence_urls": [], "safety_level": "routine", "requires_expert_confirmation": false}]}',
    )
    result = _recommendation_payload(response)
    assert isinstance(result, dict)
    assert len(result["recommendations"]) == 1
    assert result["recommendations"][0]["category"] == "Irrigation"


def test_recommendation_payload_with_no_valid_json():
    response = SimpleNamespace(parsed=None, text="Hello world")
    with pytest.raises(ValueError, match="invalid recommendation payload"):
        _recommendation_payload(response)


def test_field_health_payload_with_valid_data():
    payload = {"field_health": {"score": 87.4, "label": "excellent", "rationale": "Canopy and soil evidence look strong."}}
    result = _field_health_payload(payload)
    assert result == {"score": 87.4, "label": "excellent", "rationale": "Canopy and soil evidence look strong."}


def test_field_health_payload_missing_defaults_to_insufficient_data():
    result = _field_health_payload({})
    assert result["label"] == "insufficient_data"
    assert result["score"] is None


def test_field_health_payload_clamps_out_of_range_score():
    payload = {"field_health": {"score": 250, "label": "good", "rationale": "x"}}
    result = _field_health_payload(payload)
    assert result["score"] == 100.0


def test_field_health_payload_invalid_label_falls_back():
    payload = {"field_health": {"score": 90, "label": "amazing", "rationale": "x"}}
    result = _field_health_payload(payload)
    assert result["label"] == "insufficient_data"
    assert result["score"] is None  # insufficient_data never carries a fabricated score


def test_reconcile_field_health_forces_insufficient_data_on_bad_evidence():
    health = {"score": 90.0, "label": "excellent", "rationale": "Looks great"}
    result = _reconcile_field_health(health, [], data_quality="insufficient")
    assert result["label"] == "insufficient_data"
    assert result["score"] is None


def test_reconcile_field_health_downgrades_good_score_with_high_priority_risk():
    health = {"score": 92.0, "label": "excellent", "rationale": "Looks great"}
    recommendations = [{"priority": "high", "category": "Pest Risk"}]
    result = _reconcile_field_health(health, recommendations, data_quality="good")
    assert result["label"] == "needs_attention"
    assert result["score"] <= 60.0


def test_reconcile_field_health_leaves_consistent_output_untouched():
    health = {"score": 40.0, "label": "at_risk", "rationale": "Pest pressure detected"}
    recommendations = [{"priority": "high", "category": "Pest Risk"}]
    result = _reconcile_field_health(health, recommendations, data_quality="good")
    assert result == health


@pytest.mark.parametrize("category", [
    "Irrigation",
    "Plant Health",
    "Weather Alert",
    "Fertilizer Window",
    "Harvest Timing",
    "Pest Risk",
    "Field Monitoring",
])
def test_canonical_category_with_all_seven_predefined_categories(category):
    assert _canonical_category(category) == category
