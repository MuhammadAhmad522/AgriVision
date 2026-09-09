import json
import time
from datetime import datetime, timezone
from unittest.mock import ANY, MagicMock, patch

import pytest

from app.services import mqtt_service


class MockMessage:
    def __init__(self, topic, payload):
        self.topic = topic
        self.payload = payload


class MockSensor:
    def __init__(self, device_id="test_device_1"):
        self.id = 1
        self.device_id = device_id
        self.last_seen = None


class TestAcceptDeviceMessage:
    def test_accept_device_message_under_limit(self):
        device_id = "test_device"
        for _ in range(50):
            result = mqtt_service._accept_device_message(device_id, limit=120, window_seconds=60)
            assert result is True

    def test_accept_device_message_over_limit(self):
        device_id = "test_device"
        for i in range(121):
            result = mqtt_service._accept_device_message(device_id, limit=120, window_seconds=60)
            if i == 120:
                assert result is False
            else:
                assert result is True

    def test_accept_device_message_window_expiry(self):
        device_id = "test_device"
        times = [0.0] * 120 + [61.0]
        with patch("app.services.mqtt_service.time.monotonic", side_effect=times):
            for _ in range(120):
                result = mqtt_service._accept_device_message(device_id, limit=120, window_seconds=60)
                assert result is True
            result = mqtt_service._accept_device_message(device_id, limit=120, window_seconds=60)
            assert result is True


class TestOnMessage:
    def test_on_message_with_valid_json_payload(self):
        payload = json.dumps({"temperature": 25.5, "moisture": 60.0}).encode()
        msg = MockMessage("agrivision/sensors/test_device_1/readings", payload)

        with (
            patch("app.services.mqtt_service._event_loop", MagicMock()) as mock_loop,
            patch("app.services.mqtt_service._reading_queue", MagicMock()) as mock_queue,
        ):
            mqtt_service.on_message(None, None, msg)

            mock_loop.call_soon_threadsafe.assert_called_once()
            args = mock_loop.call_soon_threadsafe.call_args[0]
            assert args[0] is mock_queue.put_nowait
            item = args[1]
            assert item["device_id"] == "test_device_1"
            assert item["values"]["temperature"] == 25.5
            assert item["values"]["moisture"] == 60.0
            assert "timestamp" in item

    def test_on_message_with_invalid_topic_format(self):
        msg = MockMessage("wrong/topic/format", b"{}")

        with patch("app.services.mqtt_service._event_loop", MagicMock()) as mock_loop:
            mqtt_service.on_message(None, None, msg)
            mock_loop.call_soon_threadsafe.assert_not_called()

    def test_on_message_with_payload_exceeding_16kb(self):
        large_payload = b"x" * (20 * 1024)
        msg = MockMessage("agrivision/sensors/test_device_2/readings", large_payload)

        with patch("app.services.mqtt_service._event_loop", MagicMock()) as mock_loop:
            mqtt_service.on_message(None, None, msg)
            mock_loop.call_soon_threadsafe.assert_not_called()

    def test_on_message_with_unsupported_fields(self):
        payload = json.dumps({"temperature": 25, "secret_field": "hack"}).encode()
        msg = MockMessage("agrivision/sensors/test_device_3/readings", payload)

        with patch("app.services.mqtt_service._event_loop", MagicMock()) as mock_loop:
            mqtt_service.on_message(None, None, msg)
            mock_loop.call_soon_threadsafe.assert_not_called()

    def test_on_message_with_value_outside_range(self):
        payload = json.dumps({"temperature": 99999}).encode()
        msg = MockMessage("agrivision/sensors/test_device_4/readings", payload)

        with patch("app.services.mqtt_service._event_loop", MagicMock()) as mock_loop:
            mqtt_service.on_message(None, None, msg)
            mock_loop.call_soon_threadsafe.assert_not_called()


class TestWriteBatch:
    def test_write_batch_auto_discovers_new_sensor(self):
        items = [{
            "device_id": "new_device",
            "values": {"temperature": 30.0, "moisture": 50.0, "humidity": None, "ph": None, "ec": None, "npk_n": None, "npk_p": None, "npk_k": None},
            "timestamp": datetime.now(timezone.utc),
        }]

        with (
            patch("app.services.mqtt_service.SessionLocal") as mock_session_local,
            patch("app.services.mqtt_service.Sensor") as mock_sensor_cls,
            patch("app.services.mqtt_service.SensorReading") as mock_reading_cls,
        ):
            mock_db = MagicMock()
            mock_session_local.return_value = mock_db
            mock_db.query.return_value.filter.return_value.first.return_value = None

            mock_sensor_instance = MagicMock()
            mock_sensor_instance.id = 1
            mock_sensor_cls.return_value = mock_sensor_instance

            mqtt_service._write_batch(items)

            mock_sensor_cls.assert_called_once_with(
                device_id="new_device",
                sensor_type="esp32_multi_sensor",
                name="Autodiscovered new_device",
            )
            mock_db.add.assert_any_call(mock_sensor_instance)
            mock_db.flush.assert_called_once()
            mock_reading_cls.assert_called_once_with(
                sensor_id=1,
                time=items[0]["timestamp"],
                temperature=30.0,
                moisture=50.0,
                humidity=None,
                ph=None,
                ec=None,
                npk_n=None,
                npk_p=None,
                npk_k=None,
            )
            mock_db.add.assert_any_call(mock_reading_cls.return_value)
            assert mock_sensor_instance.last_seen is not None
            mock_db.commit.assert_called_once()

    def test_write_batch_updates_existing_sensor(self):
        items = [{
            "device_id": "existing_dev",
            "values": {"temperature": 22.0, "moisture": 45.0, "humidity": None, "ph": None, "ec": None, "npk_n": None, "npk_p": None, "npk_k": None},
            "timestamp": datetime.now(timezone.utc),
        }]

        with (
            patch("app.services.mqtt_service.SessionLocal") as mock_session_local,
            patch("app.services.mqtt_service.SensorReading") as mock_reading_cls,
        ):
            mock_db = MagicMock()
            mock_session_local.return_value = mock_db
            existing_sensor = MockSensor(device_id="existing_dev")
            mock_db.query.return_value.filter.return_value.first.return_value = existing_sensor

            mqtt_service._write_batch(items)

            mock_reading_cls.assert_called_once()
            assert existing_sensor.last_seen is not None
            mock_db.commit.assert_called_once()

    def test_write_batch_rollback_on_error(self):
        items = [{
            "device_id": "faulty",
            "values": {"temperature": 22.0, "moisture": 45.0, "humidity": None, "ph": None, "ec": None, "npk_n": None, "npk_p": None, "npk_k": None},
            "timestamp": datetime.now(timezone.utc),
        }]

        with patch("app.services.mqtt_service.SessionLocal") as mock_session_local:
            mock_db = MagicMock()
            mock_session_local.return_value = mock_db
            mock_db.commit.side_effect = Exception("DB error")

            mqtt_service._write_batch(items)

            mock_db.rollback.assert_called_once()
