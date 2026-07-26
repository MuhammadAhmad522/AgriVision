import serial
import json
import paho.mqtt.client as mqtt
import time
import sys

# --- Configuration ---
# Match the port found earlier in the conversation
SERIAL_PORT = '/dev/cu.usbserial-A5069RR4' 
BAUD_RATE = 115200

# Local MQTT Broker (running in Docker)
MQTT_BROKER = "localhost"
MQTT_PORT = 1883

def start_bridge():
    print(f"🚀 AgriVision Serial-to-MQTT Bridge starting...")
    print(f"🔌 Monitoring Port: {SERIAL_PORT} @ {BAUD_RATE} baud")

    ser = None
    client = None
    mqtt_loop_started = False

    try:
        # Keep ESP32 reset/boot pins inactive when the USB serial port opens.
        ser = serial.Serial(port=None, baudrate=BAUD_RATE, timeout=1)
        ser.dtr = False
        ser.rts = False
        ser.port = SERIAL_PORT
        ser.open()
    except Exception as e:
        print(f"❌ Error: Could not open serial port {SERIAL_PORT}. {e}")
        sys.exit(1)

    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        print(f"✅ Connected to MQTT Broker at {MQTT_BROKER}:{MQTT_PORT}")
    except Exception as e:
        print(f"❌ Error: Could not connect to MQTT broker. {e}")
        ser.close()
        sys.exit(1)

    client.loop_start()
    mqtt_loop_started = True

    print("📡 Waiting for ESP32 data (JSON format)...")
    
    try:
        while True:
            if ser.in_waiting > 0:
                line = ser.readline().decode('utf-8', errors='ignore').strip()
                if not line:
                    continue
                
                print(f"📥 Serial In: {line}")
                
                try:
                    # Validate JSON
                    data = json.loads(line)
                    
                    # If the ESP32 doesn't provide a device_id in the JSON, 
                    # we use a default or extract from config.
                    # Best practice: ESP32 should send its ID.
                    device_id = data.get("device_id", "ESP32_FIELD_NODE_1")
                    topic = f"agrivision/sensors/{device_id}/readings"
                    
                    # Forward to MQTT
                    client.publish(topic, line)
                    print(f"📤 MQTT Out: {topic} -> {line}")
                    
                except json.JSONDecodeError:
                    # Ignore non-JSON lines (boot logs, debug info, etc.)
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
