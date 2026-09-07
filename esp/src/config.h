#pragma once

// WiFi
constexpr const char* WIFI_SSID = "YOUR_SSID";
constexpr const char* WIFI_PASSWORD = "YOUR_PASSWORD";

// MQTT
constexpr const char* MQTT_HOST = "192.168.1.100";
constexpr uint16_t MQTT_PORT = 1883;
constexpr const char* MQTT_TOPIC_PREFIX = "agrivision/sensors";

// Device identity.
// Must match the device_id of the sensor row this node is paired to, otherwise the backend
// auto-discovers it as a new sensor with no owner and no field, and its readings become
// invisible to every client. "" derives an ID from the MAC instead, which is only safe for
// a node that has not been paired yet.
constexpr const char* DEVICE_ID = "ESP32_FIELD_NODE_1";

// --- Resistive moisture probe fault thresholds (12-bit ADC, 0-4095) ---
// This wiring reads HIGH when dry and LOW when wet (see DRY_VALUE/WET_VALUE in main.cpp),
// so an unplugged probe or a broken lead leaves the divider sitting at the dry rail. By
// value alone that is indistinguishable from very dry soil, so anything at or above this
// margin is reported as "no reading" instead of 0%.
//
// CALIBRATE THIS IN SOIL: log the raw value with the probe unplugged, then again in the
// driest soil you expect to measure, and set the threshold between the two. Dry soil still
// conducts a little, so it reads below the open-circuit rail; open air does not, and cannot
// be told apart from a disconnection.
constexpr int MOISTURE_OPEN_CIRCUIT_RAW = 4050;

// A reading pinned near ground is a shorted probe, not saturated soil — full submersion
// still reads around WET_VALUE, well above this.
constexpr int MOISTURE_SHORT_CIRCUIT_RAW = 200;
