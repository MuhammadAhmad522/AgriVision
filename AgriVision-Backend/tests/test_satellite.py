from datetime import datetime, timezone
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_current_user
from app.database import get_db
from app.main import app


def _mock_user():
    user = MagicMock()
    user.id = uuid4()
    user.firebase_uid = f"test-{uuid4()}"
    return user


def _mock_db():
    return MagicMock()


def _make_scene(**kwargs):
    scene = MagicMock()
    scene.id = uuid4()
    scene.field_id = uuid4()
    scene.provider_scene_id = "s1"
    scene.provider = "agromonitoring"
    scene.source_type = "sentinel-2"
    scene.acquired_at = datetime.now(timezone.utc)
    scene.cloud_percent = 10.0
    scene.coverage_percent = 95.0
    scene.statistics = {"ndvi": {"min": 0.1, "max": 0.9}}
    scene.ndvi_image_path = None
    scene.truecolor_image_path = None
    for k, v in kwargs.items():
        setattr(scene, k, v)
    return scene


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


@pytest.fixture
def client():
    return TestClient(app)


class TestLatest:
    def test_latest_with_existing_scene(self, client):
        user = _mock_user()
        field_id = uuid4()
        scene = _make_scene()
        db = _mock_db()

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user

        with patch("app.api.satellite.owned_field", return_value=MagicMock()):
            with patch("app.api.satellite._latest_scene", return_value=scene):
                response = client.get(f"/api/fields/{field_id}/satellite/latest")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(scene.id)
        assert data["acquired_at"] == scene.acquired_at.isoformat()
        assert data["source_type"] == scene.source_type
        assert data["cloud_percent"] == scene.cloud_percent
        assert data["coverage_percent"] == scene.coverage_percent
        assert data["statistics"] == scene.statistics
        assert data["ndvi_image_url"] is None
        assert data["truecolor_image_url"] is None

    def test_latest_with_no_scene(self, client):
        from app.core.errors import APIError

        user = _mock_user()
        field_id = uuid4()
        db = _mock_db()

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user

        with patch("app.api.satellite.owned_field", return_value=MagicMock()):
            with patch(
                "app.api.satellite._latest_scene",
                side_effect=APIError(404, "satellite_scene_unavailable", "Satellite imagery is not available yet.", retryable=True),
            ):
                response = client.get(f"/api/fields/{field_id}/satellite/latest")

        assert response.status_code == 404
        assert response.json()["error"]["code"] == "satellite_scene_unavailable"


class TestImage:
    def test_ndvi_image_with_valid_image(self, client):
        user = _mock_user()
        field_id = uuid4()
        scene = _make_scene(ndvi_image_path="/some/path.png")
        db = _mock_db()

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user

        with patch("app.api.satellite.owned_field", return_value=MagicMock()):
            with patch("app.api.satellite._latest_scene", return_value=scene):
                with patch("app.api.satellite.Path") as mock_path_cls:
                    mock_path = MagicMock()
                    mock_path_cls.return_value = mock_path
                    mock_path.resolve.return_value = mock_path
                    mock_path.is_relative_to.return_value = True
                    mock_path.is_file.return_value = True
                    with patch("app.api.satellite.FileResponse") as mock_fr:
                        mock_fr_instance = MagicMock()
                        mock_fr.return_value = mock_fr_instance
                        response = client.get(f"/api/fields/{field_id}/satellite/latest/ndvi")

        assert response.status_code == 200
        mock_fr.assert_called_once()
        assert response.json() is None or response.status_code == 200

    def test_truecolor_image_with_valid_image(self, client):
        user = _mock_user()
        field_id = uuid4()
        scene = _make_scene(truecolor_image_path="/some/path.png")
        db = _mock_db()

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user

        with patch("app.api.satellite.owned_field", return_value=MagicMock()):
            with patch("app.api.satellite._latest_scene", return_value=scene):
                with patch("app.api.satellite.Path") as mock_path_cls:
                    mock_path = MagicMock()
                    mock_path_cls.return_value = mock_path
                    mock_path.resolve.return_value = mock_path
                    mock_path.is_relative_to.return_value = True
                    mock_path.is_file.return_value = True
                    with patch("app.api.satellite.FileResponse") as mock_fr:
                        mock_fr_instance = MagicMock()
                        mock_fr.return_value = mock_fr_instance
                        response = client.get(f"/api/fields/{field_id}/satellite/latest/truecolor")

        assert response.status_code == 200
        mock_fr.assert_called_once()
        assert response.json() is None or response.status_code == 200

    def test_ndvi_image_with_missing_image(self, client):
        user = _mock_user()
        field_id = uuid4()
        scene = _make_scene(ndvi_image_path=None)
        db = _mock_db()

        app.dependency_overrides[get_db] = lambda: db
        app.dependency_overrides[get_current_user] = lambda: user

        with patch("app.api.satellite.owned_field", return_value=MagicMock()):
            with patch("app.api.satellite._latest_scene", return_value=scene):
                response = client.get(f"/api/fields/{field_id}/satellite/latest/ndvi")

        assert response.status_code == 404
        assert response.json()["error"]["code"] == "satellite_image_unavailable"
