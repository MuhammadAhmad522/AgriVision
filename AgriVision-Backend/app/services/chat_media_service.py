import hashlib
import io
import logging
import shutil
import uuid
import warnings
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from uuid import UUID

from fastapi import UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import settings
from app.core.errors import APIError

try:
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:  # pragma: no cover - dependency is present in the container image.
    pass

logger = logging.getLogger(__name__)
Image.MAX_IMAGE_PIXELS = settings.CHAT_MAX_PIXELS


@dataclass(frozen=True)
class SanitizedImage:
    data: bytes
    mime_type: str
    width: int
    height: int
    sha256: str


async def sanitize_upload(upload: UploadFile) -> SanitizedImage:
    declared = (upload.content_type or "").lower()
    allowed = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}
    if declared not in allowed:
        raise APIError(422, "unsupported_image_type", "Use a JPEG, PNG, WebP, HEIC, or HEIF image.")
    raw = await upload.read(settings.CHAT_MAX_IMAGE_BYTES + 1)
    await upload.close()
    if not raw:
        raise APIError(422, "empty_image", "An attached image is empty.")
    if len(raw) > settings.CHAT_MAX_IMAGE_BYTES:
        raise APIError(413, "image_too_large", "Each image must be 10 MB or smaller.")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(raw)) as source:
                detected = (source.format or "").upper()
                expected = {
                    "image/jpeg": {"JPEG"},
                    "image/png": {"PNG"},
                    "image/webp": {"WEBP"},
                    "image/heic": {"HEIC", "HEIF"},
                    "image/heif": {"HEIC", "HEIF"},
                }[declared]
                if detected not in expected:
                    raise APIError(422, "image_type_mismatch", "The image content does not match its declared type.")
                source.verify()
            with Image.open(io.BytesIO(raw)) as source:
                source.load()
                if source.width * source.height > settings.CHAT_MAX_PIXELS:
                    raise APIError(422, "image_dimensions_too_large", "The image dimensions are too large.")
                clean = ImageOps.exif_transpose(source).convert("RGB")
                clean.thumbnail((settings.CHAT_MAX_DIMENSION, settings.CHAT_MAX_DIMENSION), Image.Resampling.LANCZOS)
                output = io.BytesIO()
                clean.save(output, format="JPEG", quality=86, optimize=True, progressive=True, exif=b"")
                data = output.getvalue()
                return SanitizedImage(
                    data=data,
                    mime_type="image/jpeg",
                    width=clean.width,
                    height=clean.height,
                    sha256=hashlib.sha256(data).hexdigest(),
                )
    except APIError:
        raise
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise APIError(422, "invalid_image", "An attached file is not a safe, readable image.") from exc


class PrivateMediaStorage(ABC):
    @abstractmethod
    def put(self, field_id: UUID, image: SanitizedImage) -> str: ...

    @abstractmethod
    def read(self, key: str) -> bytes: ...

    @abstractmethod
    def delete(self, key: str) -> None: ...

    @abstractmethod
    def delete_field(self, field_id: UUID) -> None: ...


class LocalPrivateMediaStorage(PrivateMediaStorage):
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()

    def _path(self, key: str) -> Path:
        path = (self.root / key).resolve()
        if self.root not in path.parents:
            raise APIError(404, "attachment_not_found", "Attachment not found.")
        return path

    def put(self, field_id: UUID, image: SanitizedImage) -> str:
        key = f"{field_id}/{uuid.uuid4()}.jpg"
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(image.data)
        return key

    def read(self, key: str) -> bytes:
        path = self._path(key)
        try:
            return path.read_bytes()
        except FileNotFoundError as exc:
            raise APIError(404, "attachment_not_found", "Attachment not found.") from exc

    def delete(self, key: str) -> None:
        self._path(key).unlink(missing_ok=True)

    def delete_field(self, field_id: UUID) -> None:
        root = self._path(str(field_id))
        if root.exists():
            shutil.rmtree(root)


class GCSPrivateMediaStorage(PrivateMediaStorage):
    def __init__(self, bucket_name: str) -> None:
        from google.cloud import storage

        self.bucket = storage.Client(project=settings.GOOGLE_CLOUD_PROJECT or None).bucket(bucket_name)

    def put(self, field_id: UUID, image: SanitizedImage) -> str:
        key = f"chat/{field_id}/{uuid.uuid4()}.jpg"
        self.bucket.blob(key).upload_from_string(image.data, content_type=image.mime_type)
        return key

    def read(self, key: str) -> bytes:
        blob = self.bucket.blob(key)
        if not blob.exists():
            raise APIError(404, "attachment_not_found", "Attachment not found.")
        return blob.download_as_bytes()

    def delete(self, key: str) -> None:
        self.bucket.blob(key).delete(if_generation_match=None)

    def delete_field(self, field_id: UUID) -> None:
        for blob in self.bucket.list_blobs(prefix=f"chat/{field_id}/"):
            blob.delete()


_storage: PrivateMediaStorage | None = None


def get_chat_media_storage() -> PrivateMediaStorage:
    global _storage
    if _storage is None:
        _storage = GCSPrivateMediaStorage(settings.CHAT_GCS_BUCKET) if settings.CHAT_GCS_BUCKET else LocalPrivateMediaStorage(settings.chat_media_path)
    return _storage
