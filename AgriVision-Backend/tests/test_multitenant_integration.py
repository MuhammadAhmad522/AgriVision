import asyncio

from datetime import datetime, timedelta, timezone
import io
from uuid import uuid4
from unittest.mock import AsyncMock, Mock, patch

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.core.auth import get_current_user
from app.core.errors import APIError
from app.database import SessionLocal, get_db
from app.main import app
from app.models.db_models import (
    AIAnalysisRun,
    AIChatMessage,
    AIChatThread,
    ChatAttachment,
    Field,
    FieldDeletionJob,
    FieldObservation,
    FieldProviderLink,
    FieldRecommendation,
    ProviderCache,
    ProviderCapability,
    ProviderRequestLog,
    SatelliteScene,
    Sensor,
    SensorReading,
    User,
)


pytestmark = pytest.mark.integration


@pytest.fixture(autouse=True)
def _disable_external_provider_calls(monkeypatch):
    monkeypatch.setattr("app.api.fields.settings.AGROMONITORING_API_KEY", "")
    monkeypatch.setattr("app.services.scheduler.run_ai_by_field_id", lambda *args, **kwargs: None)


def _field_payload(name: str, sensor_id: str | None = None):
    payload = {
        "name": name,
        "crop_type": "Wheat",
        # Roughly four hectares at this latitude: valid for field registration.
        "coordinates": [
            {"longitude": 74.3000, "latitude": 31.5000},
            {"longitude": 74.3020, "latitude": 31.5000},
            {"longitude": 74.3020, "latitude": 31.5020},
            {"longitude": 74.3000, "latitude": 31.5020},
        ],
        "sensors": [],
    }
    if sensor_id:
        payload["sensors"] = [{"device_id": sensor_id, "name": "Test probe", "sensor_type": "soil"}]
    return payload


def test_field_area_must_be_between_one_and_three_thousand_hectares():
    tenant = _make_user("field-area")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    try:
        too_small = _field_payload("Too small")
        too_small["coordinates"] = [
            {"longitude": 74.3000, "latitude": 31.5000},
            {"longitude": 74.3001, "latitude": 31.5000},
            {"longitude": 74.3001, "latitude": 31.5001},
            {"longitude": 74.3000, "latitude": 31.5001},
        ]
        small_response = client.post("/api/fields", json=too_small)
        assert small_response.status_code == 422
        assert small_response.json()["error"]["code"] == "field_area_out_of_range"

        too_large = _field_payload("Too large")
        too_large["coordinates"] = [
            {"longitude": 74.0, "latitude": 31.0},
            {"longitude": 75.0, "latitude": 31.0},
            {"longitude": 75.0, "latitude": 32.0},
            {"longitude": 74.0, "latitude": 32.0},
        ]
        large_response = client.post("/api/fields", json=too_large)
        assert large_response.status_code == 422
        assert large_response.json()["error"]["code"] == "field_area_out_of_range"
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


@pytest.mark.parametrize("initial_completed,expects_continuation", [(True, False), (False, True)])
def test_field_creation_waits_for_initial_sync_and_queues_unfinished_work(initial_completed, expects_continuation):
    tenant = _make_user("initial-sync")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    try:
        with (
            patch("app.api.fields.settings.AGROMONITORING_API_KEY", "test-key"),
            patch("app.services.scheduler.sync_field_initial", AsyncMock(return_value=initial_completed)) as initial_sync,
            patch("app.api.fields._sync_field_background") as continuation,
        ):
            response = client.post("/api/fields", json=_field_payload("Initial sync field"))

        assert response.status_code == 201
        initial_sync.assert_awaited_once()
        assert continuation.called is expects_continuation
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


@pytest.mark.asyncio
async def test_provider_source_failure_does_not_rollback_successful_source():
    from app.services import scheduler

    tenant = _make_user("source-isolation")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    try:
        created = client.post("/api/fields", json=_field_payload("Source isolation field"))
        assert created.status_code == 201
        field_id = created.json()["id"]

        db = SessionLocal()
        try:
            field = db.query(Field).filter(Field.id == field_id).first()
            db.add(FieldProviderLink(field_id=field_id, provider="agromonitoring", external_id="test-polygon", sync_status="available"))
            field_uuid = field.id
            db.commit()
        finally:
            db.close()

        async def successful_source(field, db, *, force=False):
            scheduler._add_observation(
                db,
                field.id,
                "agromonitoring",
                "soil_current",
                {"moisture": 0.4},
                6,
                value=0.4,
                unit="m3/m3",
            )
            return ("available", 200, None)

        async def failed_source(field, db, *, force=False):
            raise scheduler.AgroAPIError("Provider temporarily unavailable", 503, retryable=True)

        await asyncio.gather(
            scheduler._run_source(field_uuid, "soil_current", successful_source, force=True),
            scheduler._run_source(field_uuid, "weather_forecast", failed_source, force=True),
        )

        db = SessionLocal()
        try:
            assert db.query(FieldObservation).filter(
                FieldObservation.field_id == field_uuid,
                FieldObservation.metric == "soil_current",
            ).count() == 1
            soil_state = db.query(ProviderCapability).filter(
                ProviderCapability.field_id == field_uuid,
                ProviderCapability.capability == "sync:soil_current",
            ).first()
            weather_state = db.query(ProviderCapability).filter(
                ProviderCapability.field_id == field_uuid,
                ProviderCapability.capability == "sync:weather_forecast",
            ).first()
            assert soil_state.status == "available"
            assert weather_state.status == "unavailable"
        finally:
            db.close()
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


def _make_user(prefix: str) -> User:
    db = SessionLocal()
    try:
        user = User(firebase_uid=f"{prefix}-{uuid4()}", email=f"{uuid4()}@example.test")
        db.add(user)
        db.commit()
        db.refresh(user)
        db.expunge(user)
        return user
    finally:
        db.close()


def _cleanup(*users: User):
    ids = [user.id for user in users]
    db = SessionLocal()
    try:
        db.query(Sensor).filter(Sensor.owner_id.in_(ids)).delete(synchronize_session=False)
        db.query(Field).filter(Field.owner_id.in_(ids)).delete(synchronize_session=False)
        db.query(User).filter(User.id.in_(ids)).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def _database_override():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_field_limit_enforces_max_five_active_fields():
    tenant = _make_user("field-limit")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    try:
        with patch("app.api.fields._sync_field_background", return_value=None):
            responses = [client.post("/api/fields", json=_field_payload(f"Field {i}")) for i in range(8)]

        assert [r.status_code for r in responses] == [201] * 5 + [409] * 3
        assert responses[5].json()["error"]["code"] == "active_field_limit"

        created_ids = [r.json()["id"] for r in responses[:5]]
        assert client.delete(f"/api/fields/{created_ids[0]}").status_code == 204

        replacement = client.post("/api/fields", json=_field_payload("Replacement"))
        assert replacement.status_code == 201
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


def test_field_delete_and_recreate_restores_slot():
    tenant = _make_user("recreate")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    try:
        with patch("app.api.fields._sync_field_background", return_value=None):
            created = client.post("/api/fields", json=_field_payload("Temp field"))
        assert created.status_code == 201
        field_id = created.json()["id"]

        assert client.delete(f"/api/fields/{field_id}").status_code == 204
        assert client.get(f"/api/fields/{field_id}").status_code == 404
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


def test_legacy_harvest_endpoint_returns_410():
    tenant = _make_user("harvest-410")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    try:
        with patch("app.api.fields._sync_field_background", return_value=None):
            created = client.post("/api/fields", json=_field_payload("Harvest field"))
        assert created.status_code == 201
        field_id = created.json()["id"]

        legacy = client.post(f"/api/fields/{field_id}/harvest")
        assert legacy.status_code == 410
        assert legacy.json()["error"]["code"] == "field_archiving_removed"
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


def test_sensor_cannot_be_reassigned_across_tenants():
    tenant_a = _make_user("sensor-a")
    tenant_b = _make_user("sensor-b")
    device_id = f"esp32-{uuid4()}"
    app.dependency_overrides[get_db] = _database_override
    client = TestClient(app)
    try:
        db = SessionLocal()
        try:
            db.add(Sensor(device_id=device_id, last_seen=datetime.now(timezone.utc), sensor_type="soil"))
            db.commit()
        finally:
            db.close()

        app.dependency_overrides[get_current_user] = lambda: tenant_a
        unpaired = client.post("/api/fields", json=_field_payload("Unpaired field", device_id))
        assert unpaired.status_code == 409
        assert unpaired.json()["error"]["code"] == "sensor_not_paired"

        paired = client.post("/api/sensors/pair", json={"device_id": device_id})
        assert paired.status_code == 200
        assert paired.json()["is_paired"] is True

        first = client.post("/api/fields", json=_field_payload("Owner field"))
        assert first.status_code == 201
        assigned = client.post(
            f"/api/fields/{first.json()['id']}/sensors",
            json={"device_id": device_id, "name": "Test probe", "sensor_type": "soil"},
        )
        assert assigned.status_code == 200
        assert assigned.json()["field_id"] == first.json()['id']
        listed = client.get(f"/api/fields/{first.json()['id']}/sensors")
        assert listed.status_code == 200
        assert [sensor["device_id"] for sensor in listed.json()] == [device_id]
        dashboard = client.get(f"/api/fields/{first.json()['id']}/dashboard")
        assert dashboard.status_code == 200
        assert dashboard.json()["sources"]["sensors"]["configured_count"] == 1
        assert dashboard.json()["sources"]["sensors"]["reporting_count"] == 0

        db = SessionLocal()
        try:
            db.add(
                SensorReading(
                    sensor_id=assigned.json()["id"],
                    time=datetime.now(timezone.utc),
                    temperature=27.5,
                    moisture=41,
                )
            )
            db.commit()
        finally:
            db.close()
        reporting_dashboard = client.get(f"/api/fields/{first.json()['id']}/dashboard")
        assert reporting_dashboard.json()["sources"]["sensors"]["configured_count"] == 1
        assert reporting_dashboard.json()["sources"]["sensors"]["reporting_count"] == 1

        app.dependency_overrides[get_current_user] = lambda: tenant_b
        pair_conflict = client.post("/api/sensors/pair", json={"device_id": device_id})
        assert pair_conflict.status_code == 409
        assert pair_conflict.json()["error"]["code"] == "sensor_owned_by_another_tenant"

        conflict = client.post("/api/fields", json=_field_payload("Intruder field", device_id))
        assert conflict.status_code == 409
        assert conflict.json()["error"]["code"] == "sensor_owned_by_another_tenant"
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant_a, tenant_b)


def test_two_fields_for_same_owner_return_only_their_own_dashboard_data():
    tenant = _make_user("same-owner-field-isolation")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    now = datetime.now(timezone.utc)
    try:
        first = client.post("/api/fields", json=_field_payload("North Field"))
        second_payload = _field_payload("South Field")
        second_payload["coordinates"] = [
            {"longitude": 74.4000, "latitude": 31.6000},
            {"longitude": 74.4020, "latitude": 31.6000},
            {"longitude": 74.4020, "latitude": 31.6020},
            {"longitude": 74.4000, "latitude": 31.6020},
        ]
        second = client.post("/api/fields", json=second_payload)
        assert first.status_code == second.status_code == 201
        first_id, second_id = first.json()["id"], second.json()["id"]

        db = SessionLocal()
        try:
            first_field = db.query(Field).filter(Field.id == first_id).first()
            second_field = db.query(Field).filter(Field.id == second_id).first()
            first_field.latest_ndvi = 0.21
            db.add(FieldProviderLink(field_id=first_field.id, provider="agromonitoring", external_id="test-poly-id", sync_status="available"))
            db.flush()
            second_field.latest_ndvi = 0.79
            db.add(FieldProviderLink(field_id=second_field.id, provider="agromonitoring", external_id="test-poly-id2", sync_status="available"))
            db.flush()

            first_sensor = Sensor(
                owner_id=tenant.id,
                field_id=first_id,
                device_id=f"north-{uuid4()}",
                sensor_type="soil",
            )
            second_sensor = Sensor(
                owner_id=tenant.id,
                field_id=second_id,
                device_id=f"south-{uuid4()}",
                sensor_type="soil",
            )
            db.add_all([first_sensor, second_sensor])
            db.flush()
            db.add_all(
                [
                    SensorReading(sensor_id=first_sensor.id, time=now, moisture=21, temperature=20),
                    SensorReading(sensor_id=second_sensor.id, time=now, moisture=67, temperature=29),
                    FieldObservation(
                        field_id=first_id,
                        source="test",
                        metric="soil_current",
                        payload={"moisture": 0.21, "source": "north"},
                        observed_at=now,
                        expires_at=now + timedelta(hours=6),
                    ),
                    FieldObservation(
                        field_id=second_id,
                        source="test",
                        metric="soil_current",
                        payload={"moisture": 0.67, "source": "south"},
                        observed_at=now,
                        expires_at=now + timedelta(hours=6),
                    ),
                    SatelliteScene(
                        field_id=first_id,
                        provider_scene_id=f"north-scene-{uuid4()}",
                        acquired_at=now,
                        statistics={"ndvi": {"mean": 0.21}},
                    ),
                    SatelliteScene(
                        field_id=second_id,
                        provider_scene_id=f"south-scene-{uuid4()}",
                        acquired_at=now,
                        statistics={"ndvi": {"mean": 0.79}},
                    ),
                    FieldRecommendation(
                        field_id=first_id,
                        category="Monitoring",
                        priority="low",
                        advice="Inspect the north field.",
                    ),
                    FieldRecommendation(
                        field_id=second_id,
                        category="Irrigation",
                        priority="high",
                        advice="Irrigate the south field.",
                    ),
                ]
            )
            db.commit()
        finally:
            db.close()

        first_dashboard = client.get(f"/api/fields/{first_id}/dashboard")
        second_dashboard = client.get(f"/api/fields/{second_id}/dashboard")
        assert first_dashboard.status_code == second_dashboard.status_code == 200
        north, south = first_dashboard.json(), second_dashboard.json()

        assert north["field"]["id"] == first_id
        assert south["field"]["id"] == second_id
        assert north["field"]["latest_ndvi"] == 0.21
        assert south["field"]["latest_ndvi"] == 0.79
        assert north["sources"]["soil"]["data"]["source"] == "north"
        assert south["sources"]["soil"]["data"]["source"] == "south"
        assert north["sources"]["sensors"]["data"][0]["moisture"] == 21
        assert south["sources"]["sensors"]["data"][0]["moisture"] == 67
        assert north["sources"]["satellite"]["data"]["statistics"]["ndvi"]["mean"] == 0.21
        assert south["sources"]["satellite"]["data"]["statistics"]["ndvi"]["mean"] == 0.79
        assert {item["field_id"] for item in north["recommendations"]} == {first_id}
        assert {item["field_id"] for item in south["recommendations"]} == {second_id}
        assert north["recommendations"][0]["advice"] == "Inspect the north field."
        assert south["recommendations"][0]["advice"] == "Irrigate the south field."
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


def test_permanent_delete_cascades_all_field_owned_database_data():
    tenant = _make_user("delete-cascade")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    now = datetime.now(timezone.utc)
    try:
        created = client.post("/api/fields", json=_field_payload("Cascade field"))
        assert created.status_code == 201
        field_id = created.json()["id"]
        db = SessionLocal()
        try:
            sensor = Sensor(owner_id=tenant.id, field_id=field_id, device_id=f"cascade-{uuid4()}", sensor_type="soil")
            db.add(sensor)
            db.flush()
            db.add(SensorReading(time=now, sensor_id=sensor.id, moisture=42))
            db.add(FieldObservation(field_id=field_id, source="test", metric="soil", value=42, observed_at=now, expires_at=now + timedelta(hours=1)))
            db.add(SatelliteScene(field_id=field_id, provider_scene_id=f"scene-{uuid4()}", acquired_at=now))
            run = AIAnalysisRun(field_id=field_id, provider="test", status="completed")
            db.add(run)
            db.flush()
            db.add(FieldRecommendation(field_id=field_id, analysis_run_id=run.id, category="Monitoring", priority="low", advice="Inspect the crop."))
            thread = AIChatThread(field_id=field_id)
            db.add(thread)
            db.flush()
            message = AIChatMessage(thread_id=thread.id, role="user", content="Photo", idempotency_key=f"test-{uuid4()}")
            db.add(message)
            db.flush()
            db.add(ChatAttachment(message_id=message.id, storage_key=f"{field_id}/test.jpg", mime_type="image/jpeg", byte_size=1, width=1, height=1, sha256="0" * 64))
            db.add(ProviderCapability(provider="agromonitoring", capability="uvi", field_id=field_id, status="unsupported"))
            db.add(ProviderRequestLog(provider="agromonitoring", endpoint="test", field_id=field_id, outcome="success"))
            db.add(ProviderCache(cache_key=str(uuid4()).replace("-", ""), provider="agromonitoring", endpoint="test", field_id=field_id, response_payload={"ok": True}, expires_at=now + timedelta(hours=1)))
            db.commit()
            sensor_id = sensor.id
        finally:
            db.close()

        assert client.delete(f"/api/fields/{field_id}").status_code == 204
        db = SessionLocal()
        try:
            assert db.query(Field).filter(Field.id == field_id).count() == 0
            sensor = db.query(Sensor).filter(Sensor.id == sensor_id).first()
            assert sensor is not None
            assert sensor.field_id is None
            for model in (FieldObservation, SatelliteScene, AIAnalysisRun, FieldRecommendation, AIChatThread, ProviderCapability, ProviderRequestLog, ProviderCache):
                assert db.query(model).filter(model.field_id == field_id).count() == 0
            assert db.query(AIChatMessage).join(AIChatThread, AIChatMessage.thread_id == AIChatThread.id).filter(AIChatThread.field_id == field_id).count() == 0
            assert db.query(ChatAttachment).join(AIChatMessage, ChatAttachment.message_id == AIChatMessage.id).join(AIChatThread, AIChatMessage.thread_id == AIChatThread.id).filter(AIChatThread.field_id == field_id).count() == 0
        finally:
            db.close()
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)


def _test_jpeg() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (64, 48), color=(20, 130, 60)).save(output, format="JPEG")
    return output.getvalue()


def test_multimodal_chat_is_persistent_idempotent_and_tenant_authorized():
    tenant_a = _make_user("chat-a")
    tenant_b = _make_user("chat-b")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant_a
    client = TestClient(app)
    provider = Mock()
    provider.chat = AsyncMock(return_value="Inspect the affected leaves again in daylight; the photo alone is not a definitive diagnosis.")
    key = str(uuid4())
    try:
        field_response = client.post("/api/fields", json=_field_payload("Chat field"))
        assert field_response.status_code == 201
        field_id = field_response.json()["id"]
        with patch("app.api.chat.get_ai_provider", return_value=provider):
            first = client.post(
                f"/api/fields/{field_id}/chat",
                headers={"Idempotency-Key": key},
                data={"message": "What does this leaf show?"},
                files=[("images", ("leaf.jpg", _test_jpeg(), "image/jpeg"))],
            )
            duplicate = client.post(
                f"/api/fields/{field_id}/chat",
                headers={"Idempotency-Key": key},
                data={"message": "What does this leaf show?"},
                files=[("images", ("leaf.jpg", _test_jpeg(), "image/jpeg"))],
            )
        assert first.status_code == duplicate.status_code == 200
        assert first.json() == duplicate.json()
        assert provider.chat.await_count == 1
        attachment_id = first.json()["user_message"]["attachments"][0]["id"]
        assert client.get(f"/api/fields/{field_id}/chat").status_code == 200
        assert client.get(f"/api/fields/{field_id}/chat/attachments/{attachment_id}").status_code == 200

        app.dependency_overrides[get_current_user] = lambda: tenant_b
        assert client.get(f"/api/fields/{field_id}/chat").status_code == 404
        assert client.get(f"/api/fields/{field_id}/chat/attachments/{attachment_id}").status_code == 404

        app.dependency_overrides[get_current_user] = lambda: tenant_a
        assert client.delete(f"/api/fields/{field_id}").status_code == 204
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant_a, tenant_b)


def test_ai_failure_does_not_persist_hidden_chat_messages():
    tenant = _make_user("chat-failure")
    app.dependency_overrides[get_db] = _database_override
    app.dependency_overrides[get_current_user] = lambda: tenant
    client = TestClient(app)
    provider = Mock()
    provider.chat = AsyncMock(side_effect=APIError(503, "ai_provider_failed", "AI Advisor could not answer right now.", retryable=True))
    try:
        field_response = client.post("/api/fields", json=_field_payload("Failed chat field"))
        field_id = field_response.json()["id"]
        with patch("app.api.chat.get_ai_provider", return_value=provider):
            response = client.post(
                f"/api/fields/{field_id}/chat",
                headers={"Idempotency-Key": str(uuid4())},
                data={"message": "Assess this field."},
            )
        assert response.status_code == 503
        db = SessionLocal()
        try:
            assert db.query(AIChatMessage).join(AIChatThread, AIChatMessage.thread_id == AIChatThread.id).filter(AIChatThread.field_id == field_id).count() == 0
            assert db.query(ChatAttachment).join(AIChatMessage, ChatAttachment.message_id == AIChatMessage.id).join(AIChatThread, AIChatMessage.thread_id == AIChatThread.id).filter(AIChatThread.field_id == field_id).count() == 0
        finally:
            db.close()
        assert client.delete(f"/api/fields/{field_id}").status_code == 204
    finally:
        client.close()
        app.dependency_overrides.clear()
        _cleanup(tenant)
