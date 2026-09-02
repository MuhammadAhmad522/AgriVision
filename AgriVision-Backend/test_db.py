import asyncio
from app.database import SessionLocal
from app.models.db_models import Field, SatelliteScene
from app.api.fields import get_dashboard_data
import json

def test():
    db = SessionLocal()
    field = db.query(Field).first()
    if not field:
        print("No fields")
        return
    # Mocking current user is hard because get_dashboard_data takes current_user.
    # Let's just look at the scene's ndvi_tile_url directly.
    scene = db.query(SatelliteScene).first()
    if scene:
        url = f"/api/fields/{field.id}/satellite/latest/tile/ndvi/{{z}}/{{x}}/{{y}}" if scene.ndvi_image_path else None
        print(f"URL: {url}")
        
    db.close()

if __name__ == "__main__":
    test()
