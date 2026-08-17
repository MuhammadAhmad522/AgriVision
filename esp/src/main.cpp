/**
 * @file main.cpp
 * @brief AgriVision ESP32 IoT Sensor Node Firmware
 *
 * This firmware reads environmental telemetry (soil moisture and temperature)
 * and transmits it to the AgriVision backend.
 *
 * Supported Operating Modes:
 *  - PROD_MODE: Connects to WiFi, authenticates to Mosquitto MQTT broker,
 *               supports OTA (Over-The-Air) firmware updates, and publishes every 30s.
 *  - DEV_MODE (default): Outputs JSON telemetry over USB Serial (115200 baud)
 *               for bridging via `serial_to_mqtt_bridge.py`.
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <OneWire.h>
#include <DallasTemperature.h>

#ifdef PROD_MODE
#include <ArduinoOTA.h>
#include <PubSubClient.h>
#include <WiFi.h>
#include <esp_mac.h>
#endif

#include "config.h"

// =============================================================================
// Device Identity
// =============================================================================

/// Global unique identifier for this sensor node
static String deviceId;

/**
 * @brief Initializes the unique device identifier.
 * 
 * In PROD mode:
 *  - Uses DEVICE_ID from config.h if defined.
 *  - Otherwise, derives a unique ID from the last 3 octets of the WiFi STA MAC address.
 * In DEV mode:
 *  - Uses DEVICE_ID from config.h or falls back to "ESP32_FIELD_NODE_1".
 */
static void _init_device_id() {
#ifdef PROD_MODE
  if (strlen(DEVICE_ID) > 0) {
    deviceId = DEVICE_ID;
    return;
  }
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char buf[16];
  snprintf(buf, sizeof(buf), "ESP32_%02X%02X%02X", mac[3], mac[4], mac[5]);
  deviceId = buf;
#else
  deviceId = DEVICE_ID[0] ? DEVICE_ID : "ESP32_FIELD_NODE_1";
#endif
}

// =============================================================================
// Hardware Pin Definitions & Sensor Calibration
// =============================================================================

/// Analog pin connected to the capacitive/resistive soil moisture sensor
constexpr uint8_t MOISTURE_PIN = 5;

/// Digital GPIO pin connected to DS18B20 1-Wire temperature bus
constexpr uint8_t TEMP_PIN = 6;

// --- ADC Calibration Values (12-bit ADC: 0 - 4095) ---
constexpr int DRY_VALUE = 4095;                   // Raw ADC value in completely dry soil / open air (0% moisture)
constexpr int WET_VALUE = 1200;                   // Raw ADC value fully submerged in water (100% moisture)
constexpr int DISCONNECTED_RAW_THRESHOLD = 500;   // Raw ADC values below this indicate a disconnected / floating pin

// =============================================================================
// Network & Timing Configuration (PROD Mode Only)
// =============================================================================

#ifdef PROD_MODE
/// Interval between sensor transmissions (5 seconds)
constexpr unsigned long PUBLISH_INTERVAL = 5000;

/// Exponential backoff constraints for WiFi reconnection (1s to 60s)
constexpr unsigned long WIFI_RETRY_MIN = 1000;
constexpr unsigned long WIFI_RETRY_MAX = 60000;

// OneWire bus & DS18B20 sensor driver
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensors(&oneWire);

// Network & MQTT clients
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);

// Timing state trackers
unsigned long lastPublish = 0;
unsigned long wifiRetryDelay = WIFI_RETRY_MIN;
unsigned long lastWifiAttempt = 0;
bool otaRunning = false;

/**
 * @brief Manages non-blocking WiFi connection with exponential backoff on failure.
 */
static void _connect_wifi() {
  if (WiFi.status() == WL_CONNECTED) {
    wifiRetryDelay = WIFI_RETRY_MIN;
    return;
  }
  unsigned long now = millis();
  if (now - lastWifiAttempt < wifiRetryDelay) return;
  lastWifiAttempt = now;

  Serial.print("WiFi: connecting to ");
  Serial.println(WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  // Wait up to 10 seconds for connection
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 10000) {
    delay(100);
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi: connected, IP ");
    Serial.println(WiFi.localIP());
    wifiRetryDelay = WIFI_RETRY_MIN;
  } else {
    Serial.println("WiFi: failed, retrying...");
    // Exponential backoff capped at WIFI_RETRY_MAX
    wifiRetryDelay = min(wifiRetryDelay * 2, WIFI_RETRY_MAX);
  }
}

/**
 * @brief Connects to the MQTT broker if currently disconnected.
 */
static void _connect_mqtt() {
  if (mqttClient.connected()) return;
  Serial.print("MQTT: connecting to ");
  Serial.print(MQTT_HOST);
  Serial.print(":");
  Serial.println(MQTT_PORT);

  char clientId[32];
  snprintf(clientId, sizeof(clientId), "agri_%s", deviceId.c_str());

  if (mqttClient.connect(clientId)) {
    Serial.println("MQTT: connected");
  } else {
    Serial.print("MQTT: failed, rc=");
    Serial.println(mqttClient.state());
  }
}
#else
// OneWire setup for DEV mode
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensors(&oneWire);
#endif

// =============================================================================
// Sensor Sampling Functions
// =============================================================================

/**
 * @brief Reads the temperature from the DS18B20 sensor.
 * 
 * Filters out standard Dallas error values (-127°C error / 85°C power-on reset).
 * 
 * @return float Temperature in Celsius, or NAN if reading failed / sensor disconnected.
 */
static float _read_temperature() {
  tempSensors.requestTemperatures();
  float t = tempSensors.getTempCByIndex(0);
  return (t == -127.00f || t == 85.00f || isnan(t)) ? NAN : t;
}

/**
 * @brief Reads the soil moisture level with 10-sample moving average filtering.
 * 
 * Detects floating / disconnected pins and returns NAN if no sensor is present.
 * Maps raw 12-bit ADC readings into a calibrated 0% - 100% moisture range.
 * 
 * @return float Soil moisture percentage (0.0 to 100.0), or NAN if disconnected.
 */
static float _read_moisture() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(MOISTURE_PIN);
    delay(10);
  }
  int raw = sum / 10;

  // A connected capacitive sensor outputs >= ~1000 in water; near-0 indicates floating / unconnected pin
  if (raw < DISCONNECTED_RAW_THRESHOLD) {
    return NAN;
  }

  float pct = map(raw, DRY_VALUE, WET_VALUE, 0, 100);
  return constrain(pct, 0.0f, 100.0f);
}

/**
 * @brief Packages valid sensor readings into JSON and transmits them.
 * 
 * - Only includes sensors that are physically connected and returning valid data.
 * - Always prints JSON payload to Serial (for debugging or USB dev bridge).
 * - In PROD mode: Publishes payload to MQTT topic `agrivision/sensors/{deviceId}/readings`.
 */
static void _publish_sensors() {
  float tempC = _read_temperature();
  float moisturePct = _read_moisture();

  // Create JSON telemetry document
  JsonDocument doc;
  doc["device_id"] = deviceId;
  if (!isnan(tempC)) doc["temperature"] = tempC;
  if (!isnan(moisturePct)) doc["moisture"] = moisturePct;

  char jsonBuf[512];
  serializeJson(doc, jsonBuf);
  Serial.println(jsonBuf);

#ifdef PROD_MODE
  if (mqttClient.connected()) {
    char topic[64];
    snprintf(topic, sizeof(topic), "%s/%s/readings", MQTT_TOPIC_PREFIX, deviceId.c_str());
    if (!mqttClient.publish(topic, jsonBuf)) {
      Serial.println("MQTT: publish failed");
    }
  }
#endif
}

// =============================================================================
// Arduino Setup & Main Loop
// =============================================================================

void setup() {
  Serial.begin(115200);
  delay(500);

#ifdef PROD_MODE
  Serial.println("\n--- AgriVision Node v2.0 (PROD mode: WiFi + MQTT) ---");
#else
  Serial.println("\n--- AgriVision Node v2.0 (DEV mode: USB serial) ---");
#endif

  // Configure device identifier
  _init_device_id();
  Serial.print("Device ID: ");
  Serial.println(deviceId);

  // Configure ADC: 12-bit resolution (0-4095) with full 0-3.3V range attenuation
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  tempSensors.begin();

#ifdef PROD_MODE
  // Set up MQTT broker endpoint
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);

  // Configure Over-The-Air (OTA) firmware update handlers
  ArduinoOTA.setHostname(deviceId.c_str());
  ArduinoOTA.onStart([]() { otaRunning = true; Serial.println("OTA: start"); });
  ArduinoOTA.onEnd([]() { Serial.println("OTA: end"); });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    Serial.printf("OTA: %u%%\r", progress / (total / 100));
  });
  ArduinoOTA.onError([](ota_error_t err) {
    Serial.printf("OTA: error %d\n", err);
    otaRunning = false;
  });
  ArduinoOTA.begin();
  Serial.println("OTA: ready");
#endif
}

void loop() {
#ifdef PROD_MODE
  // Handle background OTA updates
  ArduinoOTA.handle();

  // If an OTA update is in progress, yield execution to prevent interruption
  if (otaRunning) {
    delay(100);
    return;
  }

  // Ensure network connectivity
  _connect_wifi();
  if (WiFi.status() == WL_CONNECTED) {
    _connect_mqtt();
    mqttClient.loop();
  }

  // Non-blocking timer for periodic sensor publishing
  unsigned long now = millis();
  if (now - lastPublish >= PUBLISH_INTERVAL) {
    lastPublish = now;
    _publish_sensors();
  }
#else
  // In DEV mode, read sensors, output to serial, and pause for 5 seconds
  _publish_sensors();
  delay(5000);
#endif
}
