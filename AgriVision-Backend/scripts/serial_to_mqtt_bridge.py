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
    
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
    except Exception as e:
        print(f"❌ Error: Could not open serial port {SERIAL_PORT}. {e}")
        sys.exit(1)

    client = mqtt.Client()
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        print(f"✅ Connected to MQTT Broker at {MQTT_BROKER}:{MQTT_PORT}")
    except Exception as e:
        print(f"❌ Error: Could not connect to MQTT broker. {e}")
        sys.exit(1)

    client.loop_start()

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
        ser.close()
        client.loop_stop()
        client.disconnect()

if __name__ == "__main__":
    start_bridge()
