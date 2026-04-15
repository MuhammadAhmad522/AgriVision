#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// --- Configuration ---
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* mqtt_server = "192.168.X.X"; // IP address of your host machine running Docker
const int mqtt_port = 1883;

// A unique device ID linking to the PostgreSQL database Sensor row
const char* DEVICE_ID = "ESP32_FIELD_NODE_1";
String mqtt_topic = String("agrivision/sensors/") + DEVICE_ID + "/readings";

// --- Pin Definitions ---
#define MOISTURE_PIN 5
#define TEMP_PIN 6

// Calibration Values
#define DRY_VALUE 4095
#define WET_VALUE 1200

WiFiClient espClient;
PubSubClient client(espClient);

OneWire oneWire(TEMP_PIN);
DallasTemperature sensors(&oneWire);

void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);
  // Non-blocking WiFi: We don't wait here so Serial output can start immediately
  Serial.println("WiFi connection initiated in background...");
}

void reconnect() {
  // Only try to reconnect if we aren't already connected
  if (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    // Attempt to connect (non-blocking attempt)
    if (client.connect(DEVICE_ID)) {
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" - proceeding to local loop.");
      // No delay here; we'll try again on the next main loop iteration
    }
  }
}

void setup() {
  Serial.begin(115200);
  
  // ESP32-S3 ADC Configuration
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  sensors.begin();
  setup_wifi();
  
  client.setServer(mqtt_server, mqtt_port);
  
  Serial.println("\n--- AgriVision Node v1.0 (MQTT Enabled) ---");
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // 1. Read Temperature
  sensors.requestTemperatures();
  float tempC = sensors.getTempCByIndex(0);

  // 2. Read Moisture
  long readingSum = 0;
  for(int i = 0; i < 10; i++) {
    readingSum += analogRead(MOISTURE_PIN);
    delay(10);
  }
  int rawMoisture = readingSum / 10;
  float moisturePercent = map(rawMoisture, DRY_VALUE, WET_VALUE, 0, 100);
  moisturePercent = constrain(moisturePercent, 0.0, 100.0);

  // 3. Serialize to JSON Wide Schema
  JsonDocument doc;
  doc["device_id"] = DEVICE_ID;
  
  if(tempC != -127.00) {
    doc["temperature"] = tempC;
  }
  doc["moisture"] = moisturePercent;
  
  char jsonBuffer[512];
  serializeJson(doc, jsonBuffer);

  // 4. Output Raw JSON to Serial for the Bridge
  Serial.println(jsonBuffer);
  
  if (client.connected()) {
    client.publish(mqtt_topic.c_str(), jsonBuffer);
  } else {
    Serial.println("MQTT not connected, skipping WiFi publish.");
  }

  // Demo Frequency: 30 seconds (30000 ms)
  delay(30000);
}
