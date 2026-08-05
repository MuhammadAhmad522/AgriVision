#pragma once

// WiFi
constexpr const char* WIFI_SSID = "YOUR_SSID";
constexpr const char* WIFI_PASSWORD = "YOUR_PASSWORD";

// MQTT
constexpr const char* MQTT_HOST = "192.168.1.100";
constexpr uint16_t MQTT_PORT = 1883;
constexpr const char* MQTT_TOPIC_PREFIX = "agrivision/sensors";

// Device identity
constexpr const char* DEVICE_ID = "";  // "" = auto-generate from MAC
