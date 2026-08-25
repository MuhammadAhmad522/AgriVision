import asyncio
import logging

import firebase_admin
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth
from sqlalchemy.orm import Session

from app.core.errors import APIError
from app.core.config import settings
from app.database import get_db
from app.models.db_models import User

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False)


from fastapi import Depends, Request

async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise APIError(401, "authentication_required", "Please sign in to continue.")

    try:
        firebase_admin.get_app()
    except ValueError as exc:
        logger.error("Firebase Admin is unavailable; authentication is fail-closed")
        raise APIError(503, "authentication_unavailable", "Authentication is temporarily unavailable.", retryable=True) from exc

    try:
        decoded = await asyncio.wait_for(
            asyncio.to_thread(
                auth.verify_id_token,
                credentials.credentials,
                check_revoked=settings.FIREBASE_CHECK_REVOKED,
                clock_skew_seconds=settings.FIREBASE_CLOCK_SKEW_SECONDS,
            ),
            timeout=settings.FIREBASE_VERIFY_TIMEOUT_SECONDS,
        )
    except TimeoutError as exc:
        logger.warning("Firebase token verification timed out")
        raise APIError(
            503,
            "authentication_unavailable",
            "Authentication is temporarily unavailable.",
            retryable=True,
        ) from exc
    except Exception as exc:
        if type(exc).__name__ in {"TransportError", "CertificateFetchError", "ConnectionError", "ReadTimeout"}:
            logger.warning("Firebase token verification transport failed: %s", type(exc).__name__)
            raise APIError(
                503,
                "authentication_unavailable",
                "Authentication is temporarily unavailable.",
                retryable=True,
            ) from exc
        logger.info("Firebase token verification failed: %s", type(exc).__name__)
        raise APIError(401, "invalid_token", "Your session is invalid or expired.") from exc

    uid = decoded.get("uid") or decoded.get("user_id")
    if not uid:
        raise APIError(401, "invalid_token", "Your session is invalid or expired.")

    user = db.query(User).filter(User.firebase_uid == uid).first()
    email = decoded.get("email")
    if user is None and email:
        user = db.query(User).filter(User.email == email).first()
        if user is not None:
            user.firebase_uid = uid
            db.commit()
            db.refresh(user)

    if user is None:
        client = request.headers.get("X-Client", "unknown").lower()
        if client == "web":
            # Allow if they have a pending invitation
            from app.models.db_models import Invitation
            pending_invite = None
            if email:
                pending_invite = db.query(Invitation).filter(
                    Invitation.email == email,
                    Invitation.status == "pending"
                ).first()
                
            if not pending_invite:
                # Unauthorized web signup. Delete the orphaned Firebase user to keep the console clean.
                try:
                    auth.delete_user(uid)
                except Exception as e:
                    logger.warning(f"Failed to delete unauthorized Firebase user {uid}: {e}")
                raise APIError(403, "forbidden", "Access Denied. You are not authorized to access this portal.")
            
        user = User(firebase_uid=uid, email=email)
        db.add(user)
        db.commit()
        db.refresh(user)
    elif email and user.email != email:
        user.email = email
        db.commit()
        db.refresh(user)
    return user

class RequireRole:
    def __init__(self, allowed_roles: list[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, user: User = Depends(get_current_user)) -> User:
        if user.role not in self.allowed_roles and user.role != "admin":
            raise APIError(403, "forbidden", "You do not have permission to perform this action.")
        return user

