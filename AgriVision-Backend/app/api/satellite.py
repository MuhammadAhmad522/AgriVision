from pathlib import Path
from typing import Optional
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
        "ndvi_tile_url": f"/api/fields/{field_id}/satellite/latest/tile/ndvi/{{z}}/{{x}}/{{y}}" if scene.ndvi_image_path else None,
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


import httpx
from fastapi.responses import Response

@router.get("/latest/tile/{layer_type}/{z}/{x}/{y}")
async def fetch_tile(field_id: UUID, layer_type: str, z: int, x: int, y: int, v: Optional[str] = None, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    valid_layers = ["ndvi", "ndwi", "evi", "truecolor", "falsecolor", "evi2", "nri", "dswi"]
    if layer_type not in valid_layers:
        raise APIError(400, "invalid_layer", f"Unsupported satellite layer: {layer_type}")

    owned_field(db, current_user, field_id)
    scene = _latest_scene(db, field_id)
    
    # We must fetch the tile URL from Agromonitoring by searching for the scene again
    from app.services.agromonitoring_service import search_latest_scene
    from app.models.db_models import FieldProviderLink
    
    link = db.query(FieldProviderLink).filter(FieldProviderLink.field_id == field_id, FieldProviderLink.provider == "agromonitoring").first()
    if not link or not link.external_id:
        raise APIError(404, "tile_unavailable", "Satellite imagery is not properly configured.", retryable=True)
    
    # Since we need the exact scene that corresponds to the database entry,
    # we can use the `acquired_at` timestamp. 
    # But search_latest_scene uses the current 14-day window.
    # We can just fetch the tile using the scene ID parsed from provider_scene_id.
    # provider_scene_id format: "{scene_data.get('dt')}:{scene_data.get('type')}:{scene_data.get('dc')}"
    # Wait, the tile URL format is: http://sat.agromonitoring.com/image/1.0/{tile_id}/{internal_id}/ndvi/{z}/{x}/{y}.png
    # But we don't have tile_id or internal_id.
    # Let's perform a search around the acquired_at time.
    start = int(scene.acquired_at.timestamp()) - 3600
    end = int(scene.acquired_at.timestamp()) + 3600
    
    try:
        from app.services.agromonitoring_service import _request
        images = await _request(
            "GET",
            "image/search",
            params={
                "polyid": link.external_id,
                "start": start,
                "end": end
            },
            field_id=field_id,
            cache_ttl_seconds=86400,
        )
        if not images:
            raise APIError(404, "tile_unavailable", "Original scene not found.")
        
        # Match the scene by timestamp
        target_scene = next((img for img in images if img.get("dt") == int(scene.acquired_at.timestamp())), images[0])
        tile_url_template = target_scene.get("tile", {}).get(layer_type)
        if not tile_url_template:
            raise APIError(404, "tile_unavailable", "Tile URL not available in scene data.")
        
        # Build the specific tile URL. Agromonitoring already includes the appid in the template.
        actual_url = tile_url_template.replace("{z}", str(z)).replace("{x}", str(x)).replace("{y}", str(y))
        
        async with httpx.AsyncClient() as client:
            resp = await client.get(actual_url)
            if resp.status_code != 200:
                raise APIError(resp.status_code, "tile_fetch_failed", "Failed to fetch tile from provider.")
            return Response(content=resp.content, media_type=resp.headers.get("Content-Type", "image/png"), headers={"Cache-Control": "public, max-age=86400"})
    except Exception as e:
        if isinstance(e, APIError):
            if e.status_code != 404:
                import traceback
                traceback.print_exc()
            raise e
        import traceback
        traceback.print_exc()
        raise APIError(500, "internal_error", f"Error proxying tile: {str(e)}")
