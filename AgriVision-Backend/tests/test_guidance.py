"""Agronomist standing-guidance API: /api/fields/{id}/guidance.

Exercises the real Postgres test DB so FKs, the owner notification, and the
active/retracted lifecycle are all covered end to end.
"""
from unittest.mock import Mock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.database import SessionLocal, get_db
from app.main import app
from app.models.db_models import Field, FieldGuidanceDirective, User, UserNotification

pytestmark = pytest.mark.integration


def _db_override():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _make_user(prefix: str, role: str = "mobile_user") -> User:
    db = SessionLocal()
    try:
        user = User(firebase_uid=f"{prefix}-{uuid4()}", email=f"{uuid4()}@example.test", role=role)
        db.add(user)
        db.commit()
        db.refresh(user)
        db.expunge(user)
        return user
    finally:
        db.close()


def _make_field(owner: User) -> Field:
    db = SessionLocal()
    try:
        field = Field(
            owner_id=owner.id,
            name="Guidance Test Field",
            crop_type="Wheat",
            boundary="SRID=4326;POLYGON((0 0, 0.01 0, 0.01 0.01, 0 0.01, 0 0))",
            area_ha=25.0,
            status="active",
        )
        db.add(field)
        db.commit()
        db.refresh(field)
        db.expunge(field)
        return field
    finally:
        db.close()


def _cleanup(*users: User):
    ids = [u.id for u in users]
    db = SessionLocal()
    try:
        field_ids = [row[0] for row in db.query(Field.id).filter(Field.owner_id.in_(ids)).all()]
        if field_ids:
            db.query(FieldGuidanceDirective).filter(FieldGuidanceDirective.field_id.in_(field_ids)).delete(synchronize_session=False)
        db.query(UserNotification).filter(UserNotification.user_id.in_(ids)).delete(synchronize_session=False)
        db.query(Field).filter(Field.owner_id.in_(ids)).delete(synchronize_session=False)
        db.query(User).filter(User.id.in_(ids)).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


@pytest.fixture
def scenario():
    farmer = _make_user("guid-farmer", "mobile_user")
    agronomist = _make_user("guid-agro", "agronomist")
    field = _make_field(farmer)
    app.dependency_overrides[get_db] = _db_override
    rerun = Mock()
    with patch("app.api.guidance._queue_rerun", rerun):
        yield {"farmer": farmer, "agronomist": agronomist, "field": field, "rerun": rerun,
               "client": TestClient(app)}
    app.dependency_overrides.clear()
    _cleanup(farmer, agronomist)


def _as(scenario, user):
    app.dependency_overrides[get_current_user] = lambda: user


def _notifications(farmer: User):
    db = SessionLocal()
    try:
        return db.query(UserNotification).filter(
            UserNotification.user_id == farmer.id,
            UserNotification.category == "guidance_update",
        ).all()
    finally:
        db.close()


def test_add_guidance_creates_directive_notifies_owner_and_queues_rerun(scenario):
    _as(scenario, scenario["agronomist"])
    fid = scenario["field"].id

    resp = scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "Prioritise water conservation this season."})

    assert resp.status_code == 201
    body = resp.json()
    assert body["ai_rerun_queued"] is True
    assert body["deduplicated"] is False
    assert body["directive"]["status"] == "active"
    assert body["directive"]["text"] == "Prioritise water conservation this season."
    assert body["directive"]["created_by_id"] == str(scenario["agronomist"].id)

    scenario["rerun"].assert_called_once()
    assert scenario["rerun"].call_args.args[1] == fid  # (background_tasks, field_id)

    notes = _notifications(scenario["farmer"])
    assert len(notes) == 1
    assert "water conservation" in notes[0].body
    assert notes[0].field_id == fid
    assert notes[0].created_by_id == scenario["agronomist"].id
    assert notes[0].reference_type == "guidance_directive"


def test_add_identical_active_guidance_is_deduplicated(scenario):
    _as(scenario, scenario["agronomist"])
    fid = scenario["field"].id
    payload = {"text": "Watch for stem borer near the canal edge."}

    first = scenario["client"].post(f"/api/fields/{fid}/guidance", json=payload)
    second = scenario["client"].post(f"/api/fields/{fid}/guidance", json=payload)

    assert first.status_code == 201
    assert second.status_code == 201
    assert second.json()["deduplicated"] is True
    assert second.json()["ai_rerun_queued"] is False
    assert first.json()["directive"]["id"] == second.json()["directive"]["id"]

    # Only the first submission notifies + queues a re-run.
    assert scenario["rerun"].call_count == 1
    assert len(_notifications(scenario["farmer"])) == 1

    db = SessionLocal()
    try:
        assert db.query(FieldGuidanceDirective).filter(
            FieldGuidanceDirective.field_id == fid,
            FieldGuidanceDirective.status == "active",
        ).count() == 1
    finally:
        db.close()


def test_retract_guidance_notifies_and_queues_rerun(scenario):
    _as(scenario, scenario["agronomist"])
    fid = scenario["field"].id
    created = scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "Hold nitrogen; crop is near harvest."})
    directive_id = created.json()["directive"]["id"]
    scenario["rerun"].reset_mock()

    resp = scenario["client"].delete(f"/api/fields/{fid}/guidance/{directive_id}")

    assert resp.status_code == 200
    assert resp.json()["ai_rerun_queued"] is True
    assert resp.json()["directive"]["status"] == "retracted"
    scenario["rerun"].assert_called_once()

    notes = _notifications(scenario["farmer"])
    assert len(notes) == 2
    assert any("no longer follow it" in n.body for n in notes)

    db = SessionLocal()
    try:
        d = db.query(FieldGuidanceDirective).filter(FieldGuidanceDirective.id == directive_id).first()
        assert d.status == "retracted"
        assert d.retracted_by_id == scenario["agronomist"].id
        assert d.retracted_at is not None
    finally:
        db.close()


def test_retract_already_retracted_is_noop(scenario):
    _as(scenario, scenario["agronomist"])
    fid = scenario["field"].id
    created = scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "Scout for aphids twice weekly."})
    directive_id = created.json()["directive"]["id"]
    scenario["client"].delete(f"/api/fields/{fid}/guidance/{directive_id}")
    scenario["rerun"].reset_mock()

    again = scenario["client"].delete(f"/api/fields/{fid}/guidance/{directive_id}")

    assert again.status_code == 200
    assert again.json()["ai_rerun_queued"] is False
    assert again.json()["deduplicated"] is True
    scenario["rerun"].assert_not_called()
    assert len(_notifications(scenario["farmer"])) == 2  # add + first retract only


def test_farmer_cannot_add_or_retract_guidance(scenario):
    _as(scenario, scenario["farmer"])
    fid = scenario["field"].id

    resp = scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "Farmer trying to steer the AI."})

    assert resp.status_code == 403
    assert scenario["rerun"].call_count == 0
    assert len(_notifications(scenario["farmer"])) == 0


def test_farmer_can_read_guidance_on_own_field(scenario):
    _as(scenario, scenario["agronomist"])
    fid = scenario["field"].id
    scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "Irrigate lightly, avoid waterlogging."})

    _as(scenario, scenario["farmer"])
    resp = scenario["client"].get(f"/api/fields/{fid}/guidance")

    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["text"] == "Irrigate lightly, avoid waterlogging."


def test_list_orders_active_before_retracted(scenario):
    _as(scenario, scenario["agronomist"])
    fid = scenario["field"].id
    a = scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "Directive A - will be retracted."})
    scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "Directive B - stays active."})
    scenario["client"].delete(f"/api/fields/{fid}/guidance/{a.json()['directive']['id']}")

    resp = scenario["client"].get(f"/api/fields/{fid}/guidance")
    rows = resp.json()

    assert [r["status"] for r in rows] == ["active", "retracted"]

    active_only = scenario["client"].get(f"/api/fields/{fid}/guidance?include_retracted=false")
    assert [r["status"] for r in active_only.json()] == ["active"]


def test_add_guidance_on_unknown_field_returns_404(scenario):
    _as(scenario, scenario["agronomist"])
    resp = scenario["client"].post(f"/api/fields/{uuid4()}/guidance", json={"text": "Guidance for a ghost field."})
    assert resp.status_code == 404


def test_guidance_text_is_validated(scenario):
    _as(scenario, scenario["agronomist"])
    fid = scenario["field"].id
    assert scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "ab"}).status_code == 422
    assert scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "x" * 2001}).status_code == 422
    assert scenario["client"].post(f"/api/fields/{fid}/guidance", json={"text": "line1\nline2\x07"}).status_code == 422
