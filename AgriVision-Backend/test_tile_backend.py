import asyncio
from uuid import UUID
from app.database import SessionLocal
from app.models.db_models import Field
import httpx

async def main():
    db = SessionLocal()
    field = db.query(Field).first()
    if not field:
        print("No fields found")
        return
    
    print(f"Testing field {field.id}")
    async with httpx.AsyncClient() as client:
        # Mock token isn't valid, but we can see if it throws a 401. 
        # Wait, the user already provided the field ID in their logs: aec7f2ef-7091-475f-8888-8569c185f435
        # We need a valid token. Or we can just call the python function directly!
        pass

if __name__ == "__main__":
    asyncio.run(main())
