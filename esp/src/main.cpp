#include <Arduino.h>
#include <ArduinoJson.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// A unique device ID linking to the PostgreSQL database Sensor row
const char* DEVICE_ID = "ESP32_FIELD_NODE_1";

// --- Pin Definitions ---
#define MOISTURE_PIN 5
#define TEMP_PIN 6

// Calibration Values
#define DRY_VALUE 4095
#define WET_VALUE 1200

OneWire oneWire(TEMP_PIN);
DallasTemperature sensors(&oneWire);

void setup() {
  Serial.begin(115200);
  
  // ESP32-S3 ADC Configuration
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  sensors.begin();

  Serial.println("\n--- AgriVision Node v1.0 (USB Serial) ---");
}

void loop() {
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

  // Demo Frequency: 30 seconds (30000 ms)
  delay(30000);
}
