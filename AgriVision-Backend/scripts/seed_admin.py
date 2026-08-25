import sys
import os

# Add parent directory to path so we can import app modules
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.config import settings
import firebase_admin
from firebase_admin import credentials, auth
from app.database import SessionLocal
from app.models.db_models import User, UserRole

ADMIN_EMAIL = "muhammadahmad522@gmail.com"
ADMIN_PASSWORD = "Password@123"

def seed_admin():
    print(f"Seeding Super Admin: {ADMIN_EMAIL}")

    if not firebase_admin._apps:
        if settings.FIREBASE_SERVICE_ACCOUNT_PATH:
            cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
            firebase_admin.initialize_app(cred)
        else:
            print("ERROR: FIREBASE_SERVICE_ACCOUNT_PATH not set.")
            sys.exit(1)

    firebase_uid = None

    try:
        user = auth.get_user_by_email(ADMIN_EMAIL)
        print(f"User already exists in Firebase with UID: {user.uid}")
        firebase_uid = user.uid
        # Update password just to be sure
        auth.update_user(user.uid, password=ADMIN_PASSWORD)
        print("Updated Firebase user password.")
    except auth.UserNotFoundError:
        print("User not found in Firebase. Creating...")
        user = auth.create_user(
            email=ADMIN_EMAIL,
            email_verified=True,
            password=ADMIN_PASSWORD,
            display_name="Super Admin"
        )
        print(f"Created Firebase user with UID: {user.uid}")
        firebase_uid = user.uid

    db = SessionLocal()
    try:
        db_user = db.query(User).filter(User.email == ADMIN_EMAIL).first()
        if db_user:
            print(f"User already exists in Database. Current role: {db_user.role}")
            if db_user.role != UserRole.admin:
                db_user.role = UserRole.admin
                db.commit()
                print("Updated Database user role to 'admin'.")
        else:
            print("User not found in Database. Creating...")
            # Check if someone else has this firebase_uid (edge case)
            existing_uid = db.query(User).filter(User.firebase_uid == firebase_uid).first()
            if existing_uid:
                print("ERROR: Another user has this firebase_uid in the DB.")
                sys.exit(1)

            db_user = User(
                firebase_uid=firebase_uid,
                email=ADMIN_EMAIL,
                role=UserRole.admin
            )
            db.add(db_user)
            db.commit()
            print("Created Database user with role 'admin'.")
    except Exception as e:
        db.rollback()
        print(f"Database error: {e}")
        raise
    finally:
        db.close()

    print("Seeding complete.")

if __name__ == "__main__":
    seed_admin()
