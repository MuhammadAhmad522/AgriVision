import os
import json
import logging
import threading
from datetime import datetime, timezone
from uuid import UUID

import paho.mqtt.client as mqtt
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.db_models import Sensor, SensorReading

logger = logging.getLogger(__name__)

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = 1883
# Topic pattern: agrivision/sensors/<device_id>/readings
MQTT_TOPIC = "agrivision/sensors/+/readings"


def on_connect(client, userdata, flags, reason_code, properties=None):
    if reason_code == 0:
        logger.info(f"MQTT Bridge connected. Subscribing to '{MQTT_TOPIC}'")
        client.subscribe(MQTT_TOPIC)
    else:
        logger.error(f"MQTT connection failed with code {reason_code}")


def on_message(client, userdata, msg):
    """
    Called when a sensor publishes a reading.
    Expected payload (JSON):
    {
        "temperature": 25.4,
        "moisture": 62.1,
        "humidity": 55.0
    }
    """
    try:
        # Extract device_id from topic: agrivision/sensors/<device_id>/readings
        topic_parts = msg.topic.split("/")
        device_id = topic_parts[2]

        payload = json.loads(msg.payload.decode("utf-8"))

        db: Session = SessionLocal()
        try:
            sensor = db.query(Sensor).filter(Sensor.device_id == device_id).first()
            if not sensor:
                logger.info(f"MQTT: Auto-discovering new device '{device_id}'")
                sensor = Sensor(
                    device_id=device_id,
                    sensor_type="esp32_multi_sensor",
                    name=f"Autodiscovered {device_id}"
                )
                db.add(sensor)
                db.flush() # Ensure sensor has an ID

            # Generic wide-schema ingestion: Map any supported field from payload to model
            reading = SensorReading(
                sensor_id=sensor.id,
                time=datetime.now(timezone.utc),
                temperature=payload.get("temperature"),
                moisture=payload.get("moisture"),
                humidity=payload.get("humidity"),
                ph=payload.get("ph"),
                ec=payload.get("ec"),
                npk_n=payload.get("npk_n"),
                npk_p=payload.get("npk_p"),
                npk_k=payload.get("npk_k")
            )
            db.add(reading)
            sensor.last_seen = datetime.now(timezone.utc)
            db.commit()
            logger.info(f"MQTT: Saved wide-schema reading from device '{device_id}'")
        finally:
            db.close()

    except Exception as e:
        logger.error(f"MQTT message processing error: {e}")


def start_mqtt_bridge():
    """Start the MQTT client in a background thread."""
    from paho.mqtt.enums import CallbackAPIVersion
    client = mqtt.Client(CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        logger.info(f"MQTT Bridge starting, connecting to '{MQTT_BROKER}:{MQTT_PORT}'...")
        # loop_forever() blocks, so it must run in a thread
        client.loop_forever()
    except Exception as e:
        logger.error(f"MQTT Bridge could not connect: {e}")


def run_in_background():
    """Launch MQTT bridge in a daemon thread so it doesn't block FastAPI startup."""
    thread = threading.Thread(target=start_mqtt_bridge, daemon=True)
    thread.start()
    logger.info("MQTT Bridge thread started.")
