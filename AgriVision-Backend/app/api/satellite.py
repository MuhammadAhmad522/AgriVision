from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.api.fields import owned_field
from app.core.auth import get_current_user
from app.core.config import settings
from app.core.errors import APIError
from app.database import get_db
from app.models.db_models import SatelliteScene, User

router = APIRouter(prefix="/api/fields/{field_id}/satellite", tags=["Satellite"])


def _latest_scene(db: Session, field_id: UUID) -> SatelliteScene:
    scene = db.query(SatelliteScene).filter(SatelliteScene.field_id == field_id).order_by(SatelliteScene.acquired_at.desc()).first()
    if scene is None:
        raise APIError(404, "satellite_scene_unavailable", "Satellite imagery is not available yet.", retryable=True)
    return scene


@router.get("/latest")
def latest(field_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owned_field(db, current_user, field_id)
    scene = _latest_scene(db, field_id)
    return {
        "id": scene.id,
        "acquired_at": scene.acquired_at,
        "source_type": scene.source_type,
        "cloud_percent": scene.cloud_percent,
        "coverage_percent": scene.coverage_percent,
        "statistics": scene.statistics,
        "ndvi_image_url": f"/api/fields/{field_id}/satellite/latest/ndvi" if scene.ndvi_image_path else None,
        "truecolor_image_url": f"/api/fields/{field_id}/satellite/latest/truecolor" if scene.truecolor_image_path else None,
    }


def _image(field_id: UUID, kind: str, db: Session, current_user: User):
    owned_field(db, current_user, field_id)
    scene = _latest_scene(db, field_id)
    path_string = scene.ndvi_image_path if kind == "ndvi" else scene.truecolor_image_path
    path = Path(path_string) if path_string else None
    allowed_root = (settings.agro_media_path / str(field_id)).resolve()
    resolved_path = path.resolve() if path else None
    if resolved_path is None or not resolved_path.is_relative_to(allowed_root) or not resolved_path.is_file():
        raise APIError(404, "satellite_image_unavailable", "The cached satellite image is unavailable.", retryable=True)
    return FileResponse(resolved_path, media_type="image/png", headers={"Cache-Control": "private, max-age=3600"})


@router.get("/latest/ndvi")
def ndvi_image(field_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _image(field_id, "ndvi", db, current_user)


@router.get("/latest/truecolor")
def truecolor_image(field_id: UUID, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return _image(field_id, "truecolor", db, current_user)
