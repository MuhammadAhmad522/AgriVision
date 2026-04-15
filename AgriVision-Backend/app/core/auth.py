from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.db_models import User
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)
security = HTTPBearer()

async def get_current_user(res: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)):
    """
    Decodes the Firebase JWT from the 'Authorization: Bearer <TOKEN>' header.
    If valid, finds or creates the user in our PostgreSQL database based on their UID.
    """
    try:
        # Verify the ID token sent by the client
        decoded_token = auth.verify_id_token(res.credentials)
        uid = decoded_token['uid']
        email = decoded_token.get('email')
        
        # Check if user exists in our local database
        user = db.query(User).filter(User.firebase_uid == uid).first()
        
        if not user:
            # Auto-provision user record on first login
            logger.info(f"Creating new user record for Firebase UID: {uid}")
            user = User(
                firebase_uid=uid,
                email=email
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            
        return user
        
    except ValueError as e:
        logger.error(f"Invalid Firebase Token: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Firebase Auth Error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
