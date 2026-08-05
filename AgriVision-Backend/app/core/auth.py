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


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise APIError(401, "authentication_required", "Please sign in to continue.")

    if settings.ENVIRONMENT == "development" and credentials.credentials.startswith("MOCK_"):
        uid = f"dev-user-{credentials.credentials.lower()}"
        user = db.query(User).filter(User.firebase_uid == uid).first()
        if user is None:
            user = User(firebase_uid=uid, email="dev.farmer@agrivision.local")
            db.add(user)
            db.commit()
            db.refresh(user)
        return user

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
    if user is None:
        user = User(firebase_uid=uid, email=decoded.get("email"))
        db.add(user)
        db.commit()
        db.refresh(user)
    elif decoded.get("email") and user.email != decoded.get("email"):
        user.email = decoded.get("email")
        db.commit()
        db.refresh(user)
    return user
