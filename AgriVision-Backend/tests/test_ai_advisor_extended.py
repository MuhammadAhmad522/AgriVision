from types import SimpleNamespace
from unittest.mock import patch

import pytest

from app.services.ai_advisor_service import (
    _apply_safety_policy,
    _canonical_category,
    _guard_chat_response,
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
