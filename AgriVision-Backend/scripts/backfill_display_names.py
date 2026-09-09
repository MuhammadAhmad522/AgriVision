"""Backfill users.display_name from the Firebase Auth profile.

users.display_name was added after accounts already existed, and get_current_user only
fills it on each user's next authenticated request. This pulls every Firebase account's
displayName in one pass so existing farmers/staff show a name immediately.

Usage (inside the backend container):  python scripts/backfill_display_names.py
"""
import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import firebase_admin
from firebase_admin import auth, credentials

from app.core.config import settings
from app.database import SessionLocal
from app.models.db_models import User


def _ensure_firebase() -> None:
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH))


def backfill() -> None:
    _ensure_firebase()

    # uid -> display name, for every Firebase account that has one.
    names: dict[str, str] = {}
    page = auth.list_users()
    while page:
        for u in page.users:
            if u.display_name and u.display_name.strip():
                names[u.uid] = u.display_name.strip()[:255]
        page = page.get_next_page()

    print(f"Firebase returned {len(names)} accounts with a display name.")

    db = SessionLocal()
    updated = 0
    try:
        for user in db.query(User).all():
            wanted = names.get(user.firebase_uid)
            if wanted and user.display_name != wanted:
                user.display_name = wanted
                updated += 1
        db.commit()
    finally:
        db.close()

    print(f"Updated {updated} user row(s).")


if __name__ == "__main__":
    backfill()
