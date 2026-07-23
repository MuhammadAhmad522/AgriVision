import json
import logging
import threading
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from uuid import UUID

import paho.mqtt.client as mqtt
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.db_models import Sensor, SensorReading
from app.core.config import settings

logger = logging.getLogger(__name__)

MQTT_BROKER = settings.MQTT_BROKER
MQTT_PORT = settings.MQTT_PORT
# Topic pattern: agrivision/sensors/<device_id>/readings
MQTT_TOPIC = "agrivision/sensors/+/readings"
_device_events: dict[str, deque[float]] = defaultdict(deque)
_device_events_lock = threading.Lock()


def _accept_device_message(device_id: str, limit: int = 120, window_seconds: int = 60) -> bool:
    now = time.monotonic()
    with _device_events_lock:
        events = _device_events[device_id]
        while events and events[0] <= now - window_seconds:
            events.popleft()
        if len(events) >= limit:
            return False
        events.append(now)
        return True


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
        if len(topic_parts) != 4:
            raise ValueError("Invalid MQTT topic")
        device_id = topic_parts[2]
        if not 3 <= len(device_id) <= 100 or not all(character.isalnum() or character in "._:-" for character in device_id):
            raise ValueError("Invalid MQTT device ID")
        if not _accept_device_message(device_id):
            logger.warning("MQTT rate limit reached for a device")
            return

        if len(msg.payload) > 16_384:
            raise ValueError("MQTT payload exceeds 16KB")
        payload = json.loads(msg.payload.decode("utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("MQTT payload must be an object")

        reading_fields = {"temperature", "moisture", "humidity", "ph", "ec", "npk_n", "npk_p", "npk_k"}
        allowed = reading_fields | {"device_id"}
        unexpected = set(payload) - allowed
        if unexpected:
            raise ValueError(f"MQTT payload contains unsupported fields: {', '.join(sorted(unexpected))}")
        payload_device_id = payload.get("device_id")
        if payload_device_id is not None and payload_device_id != device_id:
            raise ValueError("MQTT payload device ID does not match topic")
        values = {}
        for key in reading_fields:
            value = payload.get(key)
            if value is not None:
                value = float(value)
                if not -10000 <= value <= 10000:
                    raise ValueError(f"Reading {key} is outside the accepted range")
            values[key] = value

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
                **values,
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
    if settings.MQTT_USERNAME and settings.MQTT_PASSWORD:
        client.username_pw_set(settings.MQTT_USERNAME, settings.MQTT_PASSWORD)

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
