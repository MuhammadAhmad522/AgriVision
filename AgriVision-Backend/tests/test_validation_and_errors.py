from types import SimpleNamespace
from unittest.mock import Mock, patch

import pytest
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import ValidationError

from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.core.config import settings
from app.core.errors import APIError, error_payload
from app.main import app
from app.schemas.pydantic_schemas import ChatMessageRequest, FieldWithSensorsCreate, RecommendationOutcome
from app.services.ai_advisor_service import (
    _apply_safety_policy,
    _canonical_category,
    _guard_chat_response,
    _recommendation_payload,
)


def valid_field_payload():
    return {
        "name": "  North   Field  ",
        "crop_type": " Wheat ",
        "coordinates": [
            {"longitude": 74.30, "latitude": 31.50},
            {"longitude": 74.31, "latitude": 31.50},
            {"longitude": 74.31, "latitude": 31.51},
        ],
    }


def test_field_input_is_normalized_and_strict():
    field = FieldWithSensorsCreate.model_validate(valid_field_payload())
    assert field.name == "North Field"
    assert field.crop_type == "Wheat"

    payload = valid_field_payload() | {"is_admin": True}
    with pytest.raises(ValidationError):
        FieldWithSensorsCreate.model_validate(payload)


@pytest.mark.parametrize(
    "coordinates",
    [
        [
            {"longitude": 74.30, "latitude": 31.50},
            {"longitude": 74.30, "latitude": 31.50},
            {"longitude": 74.31, "latitude": 31.51},
        ],
        [
            {"longitude": 181, "latitude": 31.50},
            {"longitude": 74.31, "latitude": 31.50},
            {"longitude": 74.31, "latitude": 31.51},
        ],
    ],
)
def test_malformed_boundaries_are_rejected(coordinates):
    payload = valid_field_payload()
    payload["coordinates"] = coordinates
    with pytest.raises(ValidationError):
        FieldWithSensorsCreate.model_validate(payload)


def test_chat_rejects_control_characters_and_oversized_messages():
    with pytest.raises(ValidationError):
        ChatMessageRequest(message="unsafe\u0000message")
    with pytest.raises(ValidationError):
        ChatMessageRequest(message="x" * 2001)


def test_recommendation_outcome_is_strict_and_sanitized():
    outcome = RecommendationOutcome(outcome="useful", notes="  Helped   after irrigation  ")
    assert outcome.notes == "Helped after irrigation"
    with pytest.raises(ValidationError):
        RecommendationOutcome(outcome="perfect", notes="unsupported enum")


def test_treatment_advice_requires_retrieved_approved_evidence():
    generated = {
        "category": "Disease",
        "priority": "high",
        "advice": "Spray fungicide at 2 ml/acre tomorrow.",
        "confidence": 0.95,
        "evidence_urls": ["https://agripunjab.gov.pk/aari-inst-Wheat"],
    }
    metadata_only = [{"url": "https://agripunjab.gov.pk/aari-inst-Wheat", "approved": True}]
    safe = _apply_safety_policy(generated, metadata_only)
    assert safe is not None
    assert safe["requires_expert_confirmation"] is True
    assert safe["safety_level"] == "high_risk"
    assert "Do not apply" in safe["advice"]
    assert safe["evidence"] == []


def test_chat_treatment_and_photo_claims_are_deterministically_guarded():
    blocked = _guard_chat_response("Spray fungicide at 2 ml/acre.", [], has_images=True)
    assert "cannot safely provide" in blocked
    visual = _guard_chat_response("The leaves appear stressed.", [], has_images=True)
    assert visual.startswith("This is a visual assessment, not a definitive diagnosis.")


def test_recommendation_payload_accepts_parsed_and_fenced_json():
    parsed = _recommendation_payload(
        SimpleNamespace(parsed={"recommendations": [{"category": "Plant Health"}]}, text="ignored")
    )
    assert parsed["recommendations"][0]["category"] == "Plant Health"

    fenced = _recommendation_payload(
        SimpleNamespace(parsed=None, text='```json\n{"recommendations":[{"category":"Irrigation"}]}\n```')
    )
    assert fenced["recommendations"][0]["category"] == "Irrigation"


def test_recommendation_categories_are_normalized_for_the_ios_cards():
    assert _canonical_category("Irrigation Management") == "Irrigation"
    assert _canonical_category("NDVI crop condition") == "Plant Health"
    assert _canonical_category("unrecognized") == "Field Monitoring"


def test_standard_error_envelope_contains_safe_metadata():
    error = APIError(429, "rate_limited", "Please wait.", retryable=True)
    assert error_payload(error, "request-123") == {
        "error": {
            "code": "rate_limited",
            "message": "Please wait.",
            "details": None,
            "retryable": True,
            "request_id": "request-123",
        }
    }


@pytest.mark.asyncio
async def test_authentication_fails_closed_when_firebase_is_unavailable():
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="not-a-real-token")
    with patch("app.core.auth.firebase_admin.get_app", side_effect=ValueError("not initialized")):
        with pytest.raises(APIError) as raised:
            await get_current_user(credentials=credentials, db=Mock())
    assert raised.value.status_code == 503
    assert raised.value.code == "authentication_unavailable"


@pytest.mark.asyncio
async def test_authentication_allows_only_configured_bounded_clock_skew():
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="fresh-id-token")
    existing_user = Mock()
    db = Mock()
    db.query.return_value.filter.return_value.first.return_value = existing_user

    with patch("app.core.auth.firebase_admin.get_app"), patch(
        "app.core.auth.auth.verify_id_token",
        return_value={"uid": "firebase-user"},
    ) as verify:
        result = await get_current_user(credentials=credentials, db=db)

    assert result is existing_user
    verify.assert_called_once_with(
        "fresh-id-token",
        check_revoked=settings.FIREBASE_CHECK_REVOKED,
        clock_skew_seconds=settings.FIREBASE_CLOCK_SKEW_SECONDS,
    )


@pytest.mark.asyncio
async def test_authentication_timeout_is_retryable():
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="slow-token")

    async def raise_timeout(awaitable, timeout):
        awaitable.close()
        raise TimeoutError

    with patch("app.core.auth.firebase_admin.get_app"), patch(
        "app.core.auth.asyncio.wait_for",
        side_effect=raise_timeout,
    ):
        with pytest.raises(APIError) as raised:
            await get_current_user(credentials=credentials, db=Mock())

    assert raised.value.status_code == 503
    assert raised.value.code == "authentication_unavailable"
    assert raised.value.retryable is True


def test_oversized_payload_and_untrusted_request_id_are_handled_safely():
    client = TestClient(app)
    try:
        response = client.post(
            "/",
            headers={"Content-Length": "1048577", "X-Request-ID": "invalid request id"},
        )
        assert response.status_code == 413
        assert response.json()["error"]["code"] == "payload_too_large"
        assert response.headers["X-Request-ID"] != "invalid request id"
        assert response.json()["error"]["request_id"] == response.headers["X-Request-ID"]
    finally:
        client.close()
