import tempfile
from pathlib import Path
from uuid import uuid4

import pytest

from app.core.errors import APIError
from app.services.chat_media_service import LocalPrivateMediaStorage, SanitizedImage


class TestLocalPrivateMediaStorage:
    def test_put_and_read_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            storage = LocalPrivateMediaStorage(Path(tmp))
            image = SanitizedImage(
                data=b"fake-jpeg-data",
                mime_type="image/jpeg",
                width=100,
                height=200,
                sha256="abc123",
            )
            field_id = uuid4()
            key = storage.put(field_id, image)
            data = storage.read(key)
            assert data == b"fake-jpeg-data"

    def test_put_creates_directories(self):
        with tempfile.TemporaryDirectory() as tmp:
            storage = LocalPrivateMediaStorage(Path(tmp))
            image = SanitizedImage(
                data=b"data",
                mime_type="image/jpeg",
                width=1,
                height=1,
                sha256="x",
            )
            field_id = uuid4()
            key = storage.put(field_id, image)
            dir_path = Path(tmp).resolve() / str(field_id)
            assert dir_path.is_dir()

    def test_delete_removes_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            storage = LocalPrivateMediaStorage(Path(tmp))
            image = SanitizedImage(
                data=b"data",
                mime_type="image/jpeg",
                width=1,
                height=1,
                sha256="x",
            )
            field_id = uuid4()
            key = storage.put(field_id, image)
            storage.delete(key)
            with pytest.raises(APIError) as exc:
                storage.read(key)
            assert exc.value.status_code == 404

    def test_delete_field_removes_all_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            storage = LocalPrivateMediaStorage(Path(tmp))
            image = SanitizedImage(
                data=b"data",
                mime_type="image/jpeg",
                width=1,
                height=1,
                sha256="x",
            )
            field_id = uuid4()
            storage.put(field_id, image)
            storage.put(field_id, image)
            storage.put(field_id, image)
            storage.delete_field(field_id)
            root = Path(tmp).resolve() / str(field_id)
            assert not root.exists()

    def test_path_traversal_protection(self):
        with tempfile.TemporaryDirectory() as tmp:
            storage = LocalPrivateMediaStorage(Path(tmp))
            with pytest.raises(APIError) as exc:
                storage._path("../../etc/passwd")
            assert exc.value.status_code == 404

    def test_read_nonexistent_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            storage = LocalPrivateMediaStorage(Path(tmp))
            with pytest.raises(APIError) as exc:
                storage.read("nonexistent/file.jpg")
            assert exc.value.status_code == 404
