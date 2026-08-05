import os
import serial
import serial.tools.list_ports
import json
import paho.mqtt.client as mqtt
import time
import sys

# --- Configuration ---
DEFAULT_SERIAL_PORT = os.environ.get("SERIAL_PORT", "/dev/cu.usbserial-A5069RR4")
BAUD_RATE = int(os.environ.get("BAUD_RATE", 115200))

# Local MQTT Broker (running in Docker)
MQTT_BROKER = os.environ.get("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", 1883))

def find_serial_port():
    if os.environ.get("SERIAL_PORT") == "mock" or "--mock" in sys.argv:
        return "mock"
    if os.path.exists(DEFAULT_SERIAL_PORT) and "usb" in DEFAULT_SERIAL_PORT.lower():
        return DEFAULT_SERIAL_PORT
    ports = list(serial.tools.list_ports.comports())
    for p in ports:
        dev_lower = p.device.lower()
        desc_lower = (p.description or "").lower()
        if any(ignore in dev_lower for ignore in ["debug-console", "bluetooth", "wavepro", "ca-6928"]):
            continue
        if any(keyword in dev_lower or keyword in desc_lower for keyword in ["usbserial", "usbmodem", "ch340", "cp210", "uart", "ftdi", "usb"]):
            print(f"🔍 Auto-detected USB serial device: {p.device} ({p.description})")
            return p.device
    return None

def start_bridge():
    port = find_serial_port()
    print(f"🚀 AgriVision Serial-to-MQTT Bridge starting...")

    if port is None:
        print("❌ Error: No physical USB serial port detected!")
        print("   Troubleshooting steps:")
        print("   1. Ensure your ESP32 board is plugged directly into a Mac USB port.")
        print("   2. Verify your micro-USB / USB-C cable is a DATA cable (not power-only).")
        print("   3. Install the CH340 / CP210x USB driver for macOS if needed.")
        print("   4. To test without physical hardware, run:")
        print("      python3 scripts/serial_to_mqtt_bridge.py --mock")
        sys.exit(1)

    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        print(f"✅ Connected to MQTT Broker at {MQTT_BROKER}:{MQTT_PORT}")
    except Exception as e:
        print(f"❌ Error: Could not connect to MQTT broker at {MQTT_BROKER}:{MQTT_PORT}. {e}")
        sys.exit(1)

    client.loop_start()

    if port == "mock":
        print("🧪 RUNNING IN MOCK SIMULATOR MODE (Generating sensor telemetry every 3s)...")
        print("📡 Press Ctrl+C to stop.\n")
        import random
        device_id = os.environ.get("DEVICE_ID", "ESP32_FIELD_NODE_1")
        topic = f"agrivision/sensors/{device_id}/readings"
        try:
            while True:
                payload = {
                    "device_id": device_id,
                    "temperature": round(random.uniform(24.0, 32.0), 1),
                    "moisture": round(random.uniform(35.0, 55.0), 1),
                    "humidity": round(random.uniform(50.0, 70.0), 1),
                    "ph": round(random.uniform(6.2, 7.2), 1),
                    "ec": round(random.uniform(1.0, 1.8), 2),
                    "npk_n": round(random.uniform(110.0, 160.0), 1),
                    "npk_p": round(random.uniform(30.0, 60.0), 1),
                    "npk_k": round(random.uniform(150.0, 200.0), 1),
                }
                line = json.dumps(payload)
                client.publish(topic, line)
                print(f"📥 [MOCK SENSOR] 📤 MQTT Out: {topic} -> {line}")
                time.sleep(3.0)
        except KeyboardInterrupt:
            print("\n🛑 Mock Bridge shutting down...")
        finally:
            client.disconnect()
            sys.exit(0)

    print(f"🔌 Monitoring Serial Port: {port} @ {BAUD_RATE} baud")
    ser = None
    try:
        ser = serial.Serial(port=None, baudrate=BAUD_RATE, timeout=1)
        ser.dtr = False
        ser.rts = False
        ser.port = port
        ser.open()
    except Exception as e:
        print(f"❌ Error: Could not open serial port {port}. {e}")
        client.disconnect()
        sys.exit(1)

    print("📡 Waiting for ESP32 data (JSON format)...")
    
    try:
        while True:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if not line:
                    continue
                
                print(f"📥 Serial In: {line}")
                
                try:
                    data = json.loads(line)
                    device_id = data.get("device_id", "ESP32_FIELD_NODE_1")
                    topic = f"agrivision/sensors/{device_id}/readings"
                    client.publish(topic, line)
                    print(f"📤 MQTT Out: {topic} -> {line}")
                except json.JSONDecodeError:
                    pass
            
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        print("\n🛑 Bridge shutting down...")
    finally:
        if client is not None:
            try:
                client.disconnect()
            except Exception:
                pass

            if mqtt_loop_started:
                try:
                    client.loop_stop()
                except KeyboardInterrupt:
                    print("\n🛑 Shutdown interrupted; exiting.")

        if ser is not None and ser.is_open:
            ser.close()

if __name__ == "__main__":
    start_bridge()
