import os
from sqlalchemy import text
from app.database import engine, Base
from app.models.db_models import User, Field, Sensor, SensorReading

def init_db():
    print("Initializing Database...")
    
    with engine.connect() as conn:
        print("Creating Extensions...")
        # Needs commit for extension creation
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS timescaledb;"))
        conn.commit()

    print("Creating Tables from SQLAlchemy metadata...")
    Base.metadata.create_all(bind=engine)
    
    with engine.connect() as conn:
        print("Ensuring sensors table field_id is nullable (Fix for auto-discovery issue)...")
        try:
            conn.execute(text("ALTER TABLE sensors ALTER COLUMN field_id DROP NOT NULL;"))
            conn.commit()
            print("Successfully made field_id nullable.")
        except Exception as e:
            print(f"Notes on altering table: {e}")

    with engine.connect() as conn:
        print("Ensuring sensor_readings is a hypertable...")
        # Check if it's already a hypertable
        result = conn.execute(text(
            "SELECT count(*) FROM _timescaledb_catalog.hypertable WHERE hypertable_name = 'sensor_readings';"
        )).scalar()
        
        if result == 0:
            print("Converting sensor_readings to hypertable...")
            conn.execute(text("SELECT create_hypertable('sensor_readings', 'time');"))
            conn.commit()
            print("Hypertable created Successfully.")
        else:
            print("Hypertable already exists.")

    print("Database Initialization Complete.")

if __name__ == "__main__":
    init_db()
