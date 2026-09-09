import io

import pytest
from fastapi import UploadFile
from PIL import Image

from app.core.errors import APIError
from app.services.chat_media_service import sanitize_upload


def _jpeg_with_metadata(size=(2400, 1200)) -> bytes:
    output = io.BytesIO()
    image = Image.new("RGB", size, color=(24, 120, 60))
    exif = Image.Exif()
    exif[0x010E] = "private field note"
    image.save(output, format="JPEG", exif=exif)
    return output.getvalue()


@pytest.mark.asyncio
async def test_image_is_resized_reencoded_and_metadata_removed():
    upload = UploadFile(filename="field.jpg", file=io.BytesIO(_jpeg_with_metadata()), headers={"content-type": "image/jpeg"})
    result = await sanitize_upload(upload)
    assert result.mime_type == "image/jpeg"
    assert max(result.width, result.height) == 2048
    with Image.open(io.BytesIO(result.data)) as clean:
        assert len(clean.getexif()) == 0


@pytest.mark.asyncio
async def test_declared_type_spoofing_is_rejected():
    upload = UploadFile(filename="field.png", file=io.BytesIO(_jpeg_with_metadata((100, 100))), headers={"content-type": "image/png"})
    with pytest.raises(APIError) as raised:
        await sanitize_upload(upload)
    assert raised.value.code == "image_type_mismatch"
