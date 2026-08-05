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

// --- Device Identity ---
static String deviceId;

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

// --- Pin Definitions ---
constexpr uint8_t MOISTURE_PIN = 5;
constexpr uint8_t TEMP_PIN = 6;

// --- Calibration ---
constexpr int DRY_VALUE = 4095;
constexpr int WET_VALUE = 1200;

#ifdef PROD_MODE
// --- Timing (milliseconds) ---
constexpr unsigned long PUBLISH_INTERVAL = 30'000;
constexpr unsigned long WIFI_RETRY_MIN = 1'000;
constexpr unsigned long WIFI_RETRY_MAX = 60'000;

OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensors(&oneWire);
WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);
unsigned long lastPublish = 0;
unsigned long wifiRetryDelay = WIFI_RETRY_MIN;
unsigned long lastWifiAttempt = 0;
bool otaRunning = false;

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

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 10'000) {
    delay(100);
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi: connected, IP ");
    Serial.println(WiFi.localIP());
    wifiRetryDelay = WIFI_RETRY_MIN;
  } else {
    Serial.println("WiFi: failed, retrying...");
    wifiRetryDelay = min(wifiRetryDelay * 2, WIFI_RETRY_MAX);
  }
}

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
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensors(&oneWire);
#endif

static float _read_temperature() {
  tempSensors.requestTemperatures();
  float t = tempSensors.getTempCByIndex(0);
  return (t == -127.00f || t == 85.00f || isnan(t)) ? NAN : t;
}

static float _read_moisture() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(MOISTURE_PIN);
    delay(10);
  }
  int raw = sum / 10;
  float pct = map(raw, DRY_VALUE, WET_VALUE, 0, 100);
  return constrain(pct, 0.0f, 100.0f);
}

static void _publish_sensors() {
  float tempC = _read_temperature();
  float moisturePct = _read_moisture();

  JsonDocument doc;
  doc["device_id"] = deviceId;
  if (!isnan(tempC)) doc["temperature"] = tempC;
  doc["moisture"] = moisturePct;

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

void setup() {
  Serial.begin(115200);
  delay(500);

#ifdef PROD_MODE
  Serial.println("\n--- AgriVision Node v2.0 (PROD mode: WiFi + MQTT) ---");
#else
  Serial.println("\n--- AgriVision Node v2.0 (DEV mode: USB serial) ---");
#endif

  _init_device_id();
  Serial.print("Device ID: ");
  Serial.println(deviceId);

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  tempSensors.begin();

#ifdef PROD_MODE
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);

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
  ArduinoOTA.handle();

  if (otaRunning) {
    delay(100);
    return;
  }

  _connect_wifi();
  if (WiFi.status() == WL_CONNECTED) {
    _connect_mqtt();
    mqttClient.loop();
  }

  unsigned long now = millis();
  if (now - lastPublish >= PUBLISH_INTERVAL) {
    lastPublish = now;
    _publish_sensors();
  }
#else
  _publish_sensors();
  delay(30000);
#endif
}
