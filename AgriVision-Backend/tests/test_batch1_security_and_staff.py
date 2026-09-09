import pytest
from uuid import uuid4
from datetime import datetime, timezone
import httpx
from unittest.mock import patch, MagicMock

from app.database import SessionLocal
from app.models.db_models import User, UserRole, Invitation, Field, Sensor, SensorReading
from app.services.agromonitoring_service import delete_polygon
from app.api.fields import field_readable_by, owned_field
from app.core.errors import APIError


from sqlalchemy import text


@pytest.fixture
def clean_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        try:
            for t in ("invitations", "sensor_readings", "sensors", "fields", "users"):
                db.execute(text(f"DELETE FROM {t} CASCADE"))
            db.commit()
        except Exception:
            db.rollback()
        finally:
            db.close()


def test_case_insensitive_email_and_invite_upgrade(clean_db):
    email = f"TestFarmer_{uuid4()}@Example.COM"
    inviter = User(id=uuid4(), email=f"admin_{uuid4()}@example.com", firebase_uid=f"fb-adm-{uuid4()}", role=UserRole.admin)
    clean_db.add(inviter)
    clean_db.commit()

    # 1. User signs up as mobile user with uppercase email
    farmer = User(id=uuid4(), email=email.lower(), firebase_uid=f"fb-farm-{uuid4()}", role=UserRole.mobile_user)
    clean_db.add(farmer)
    clean_db.commit()

    # 2. Admin invites the farmer to become an agronomist using mixed-case email
    invite = Invitation(
        id=uuid4(),
        email=email.upper(),
        role=UserRole.agronomist,
        status="pending",
        invited_by_id=inviter.id,
    )
    clean_db.add(invite)
    clean_db.commit()

    # 3. Simulate get_current_user logic for existing user with invite
    from app.core.auth import get_current_user
    mock_request = MagicMock()
    mock_request.headers.get.return_value = "web"
    
    mock_creds = MagicMock()
    mock_creds.scheme = "Bearer"
    mock_creds.credentials = "valid_token"

    with patch("app.core.auth.firebase_admin.get_app"), patch("app.core.auth.auth.verify_id_token", return_value={"uid": farmer.firebase_uid, "email": email}):
        import asyncio
        authed_user = asyncio.run(get_current_user(mock_request, mock_creds, clean_db))

    assert authed_user.id == farmer.id
    assert authed_user.role == UserRole.agronomist
    clean_db.refresh(invite)
    assert invite.status == "accepted"


def test_staff_read_access_for_other_farmer_field(clean_db):
    farmer = User(id=uuid4(), email=f"farmer_{uuid4()}@example.com", firebase_uid=f"fb-f-{uuid4()}", role=UserRole.mobile_user)
    agronomist = User(id=uuid4(), email=f"agro_{uuid4()}@example.com", firebase_uid=f"fb-a-{uuid4()}", role=UserRole.agronomist)
    clean_db.add_all([farmer, agronomist])
    clean_db.commit()

    field = Field(
        id=uuid4(),
        owner_id=farmer.id,
        name="Farmer Test Field",
        boundary="SRID=4326;POLYGON((73.0 31.0, 73.01 31.0, 73.01 31.01, 73.0 31.01, 73.0 31.0))",
        area_ha=10.0,
        crop_type="Wheat",
        status="active",
    )
    clean_db.add(field)
    clean_db.commit()

    # 1. Farmer has read access
    read_by_farmer = field_readable_by(clean_db, farmer, field.id)
    assert read_by_farmer.id == field.id

    # 2. Staff (agronomist) has read access
    read_by_staff = field_readable_by(clean_db, agronomist, field.id)
    assert read_by_staff.id == field.id

    # 3. Another farmer does NOT have read access (404)
    intruder = User(id=uuid4(), email=f"intruder_{uuid4()}@example.com", firebase_uid=f"fb-i-{uuid4()}", role=UserRole.mobile_user)
    clean_db.add(intruder)
    clean_db.commit()

    with pytest.raises(APIError) as exc_info:
        field_readable_by(clean_db, intruder, field.id)
    assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_delete_polygon_404_idempotent():
    # When polygon is already 404, delete_polygon should not raise
    resp = httpx.Response(status_code=404, request=httpx.Request("DELETE", "http://test"))
    http_err = httpx.HTTPStatusError("Not Found", request=resp.request, response=resp)
    
    with patch("app.services.agromonitoring_service._request", side_effect=http_err):
        # Should not raise exception
        await delete_polygon("test-polygon-id-404")
