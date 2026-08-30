import asyncio
import json
import logging
import threading
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from typing import Any

import paho.mqtt.client as mqtt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import SessionLocal
from app.models.db_models import Sensor, SensorReading

logger = logging.getLogger(__name__)

MQTT_BROKER = settings.MQTT_BROKER
MQTT_PORT = settings.MQTT_PORT
MQTT_TOPIC = "agrivision/sensors/+/readings"

_device_events: dict[str, deque[float]] = defaultdict(deque)
_device_events_lock = threading.Lock()

_reading_queue: asyncio.Queue[dict[str, Any]] | None = None
_event_loop: asyncio.AbstractEventLoop | None = None

BATCH_SIZE = 50


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
    Fast path: validate and enqueue reading. DB writes happen in the
    background _db_writer_loop so the MQTT network thread is never blocked.
    """
    try:
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
            raise ValueError(f"MQTT payload contains additional fields: {', '.join(sorted(unexpected))}")
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

        now = datetime.now(timezone.utc)
        item = {"device_id": device_id, "values": values, "timestamp": now}
        if _event_loop and _reading_queue:
            _event_loop.call_soon_threadsafe(_reading_queue.put_nowait, item)
        else:
            logger.warning("MQTT: async consumer not ready — dropping reading")
    except Exception as e:
        logger.error(f"MQTT message processing error: {e}")


def _write_batch(items: list[dict]) -> None:
    """Write a batch of sensor readings to DB in a single transaction."""
    db: Session = SessionLocal()
    try:
        for item in items:
            device_id = item["device_id"]
            sensor = db.query(Sensor).filter(Sensor.device_id == device_id).first()
            if not sensor:
                logger.info(f"MQTT: Auto-discovering new device '{device_id}'")
                sensor = Sensor(
                    device_id=device_id,
                    sensor_type="esp32_multi_sensor",
                    name=f"Autodiscovered {device_id}",
                )
                db.add(sensor)
                db.flush()

            reading = SensorReading(
                sensor_id=sensor.id,
                time=item["timestamp"],
                **item["values"],
            )
            db.add(reading)
            sensor.last_seen = item["timestamp"]
        db.commit()
        logger.info(f"MQTT: Wrote batch of {len(items)} reading(s)")
    except Exception:
        db.rollback()
        logger.exception("MQTT batch write failed — %d reading(s) lost", len(items))
    finally:
        db.close()


async def _db_writer_loop():
    """Consume from the async queue and batch-write readings to the database."""
    try:
        while True:
            item = await _reading_queue.get()
            batch = [item]
            for _ in range(BATCH_SIZE - 1):
                if _reading_queue.empty():
                    break
                batch.append(_reading_queue.get_nowait())
            await asyncio.to_thread(_write_batch, batch)
    except asyncio.CancelledError:
        remaining = []
        while not _reading_queue.empty():
            remaining.append(_reading_queue.get_nowait())
        if remaining:
            _write_batch(remaining)


def _start_mqtt_bridge():
    """Start the MQTT client in a background thread (blocking)."""
    from paho.mqtt.enums import CallbackAPIVersion

    client = mqtt.Client(CallbackAPIVersion.VERSION2)
    client.on_connect = on_connect
    client.on_message = on_message
    if settings.MQTT_USERNAME and settings.MQTT_PASSWORD:
        client.username_pw_set(settings.MQTT_USERNAME, settings.MQTT_PASSWORD)

    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        logger.info(f"MQTT Bridge starting, connecting to '{MQTT_BROKER}:{MQTT_PORT}'...")
        client.loop_forever()
    except Exception as e:
        logger.error(f"MQTT Bridge could not connect: {e}")


async def start_background_tasks():
    """Initialise the async queue and launch the MQTT bridge + DB writer."""
    global _reading_queue, _event_loop
    _reading_queue = asyncio.Queue()
    _event_loop = asyncio.get_running_loop()
    thread = threading.Thread(target=_start_mqtt_bridge, daemon=True)
    thread.start()
    logger.info("MQTT Bridge thread started.")
    consumer = asyncio.create_task(_db_writer_loop())
    return consumer
