import asyncio
from uuid import UUID
from app.database import SessionLocal
from app.models.db_models import Field, User
from app.api.satellite import ndvi_tile

async def main():
    db = SessionLocal()
    field = db.query(Field).first()
    user = db.query(User).filter(User.id == field.user_id).first()
    
    # 16/46307/26717
    try:
        response = await ndvi_tile(field_id=field.id, z=16, x=46307, y=26717, db=db, current_user=user)
        print("Response status:", response.status_code)
    except Exception as e:
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
