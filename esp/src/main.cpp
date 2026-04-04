#include <Arduino.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// Pin Definitions
#define MOISTURE_PIN 5
#define TEMP_PIN 6

// Calibration Values (Adjust these based on your water test)
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
  
  Serial.println("\n--- AgriVision Node v1.0 ---");
  Serial.println("Pin 5: Moisture (Resistive)");
  Serial.println("Pin 6: Temperature (DS18B20)");
}

void loop() {
  // 1. Read Temperature
  sensors.requestTemperatures();
  float tempC = sensors.getTempCByIndex(0);

  // 2. Read Moisture (Average of 10 readings for stability)
  long readingSum = 0;
  for(int i = 0; i < 10; i++) {
    readingSum += analogRead(MOISTURE_PIN);
    delay(10);
  }
  int rawMoisture = readingSum / 10;
  int moisturePercent = map(rawMoisture, DRY_VALUE, WET_VALUE, 0, 100);
  moisturePercent = constrain(moisturePercent, 0, 100);

  // 3. The "Brain-Ready" Output
  Serial.print(">> [DATA] ");
  if(tempC == -127.00) {
    Serial.print("Temp: ERROR | ");
  } else {
    Serial.print("Temp: "); Serial.print(tempC); Serial.print("C | ");
  }
  
  Serial.print("Moisture: "); Serial.print(moisturePercent); Serial.println("%");

  delay(2000); 
}