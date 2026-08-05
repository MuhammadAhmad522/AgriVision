# 1. Scope of the Project

## 1.1 Project Overview
AgriVision is an intelligent precision agriculture platform designed to act as an interactive agronomy advisor. The core objective of the system is to continuously analyze crop health and environmental conditions by synthesizing data from three distinct layers: macro-level satellite telemetry, micro-level IoT field sensors, and direct user input via an AI chatbot. By aggregating this tri-source data, AgriVision interactively guides farmers through the entire crop lifecycle, providing timely, field-specific insights to optimize yield and mitigate risks.

## 1.2 Target Audience
The primary end-users are small to medium-scale farmers and agricultural stakeholders. The platform is designed to bridge the gap between complex agronomic data and accessible mobile technology, translating rich environmental telemetry into simple, interactive conversational guidance that any farmer can act upon.

## 1.3 In-Scope Functionalities
The core functional deliverables of the AgriVision capstone project include:
*   **Tri-Source Data Ingestion & Synthesis:** 
    1.  **Satellite Integration:** Defining field polygons to retrieve automated Sentinel-2 imagery, NDVI vegetation indices, weather forecasts, and soil profiles.
    2.  **IoT Sensor Integration:** Ingesting real-time ground telemetry (Temperature, Moisture, Humidity, pH, EC, NPK) from physical ESP32 sensor nodes via a local MQTT bridge.
    3.  **User Input (Visual & Text):** Allowing farmers to upload diagnostic photos of their crops and ask natural-language questions.
*   **Interactive AI Agronomist:** A central conversational agent (powered by a multi-modal RAG pipeline) that processes the ingested satellite and sensor data alongside user uploads. It acts as a localized agricultural expert, interactively answering farmer queries regarding crop diseases, irrigation needs, and fertilizer application.
*   **Automated Field Recommendations (Background Reasoning):** The generation of customized, safe, step-by-step guidance for field management (e.g., Irrigation, Pest Risk, Fertilizer Windows) based on continuous analysis. This is driven by asynchronous background scheduling loops (`ai_reasoning_loop`, `external_data_loop`) that automatically monitor the field's data streams and trigger AI evaluations without requiring manual user intervention.
*   **Native Mobile Client:** A comprehensive iOS application featuring interactive dashboards, field boundary management, and the AI chat interface.

## 1.4 Out of Scope
To maintain a clear and achievable boundary for the final capstone presentation, the following features are not included in the current system:
*   **Automated Hardware Actuation:** The system will *recommend* when to irrigate or apply fertilizer based on sensor deficits, but it will not automatically actuate physical water valves or farming hardware.
*   **Live Drone Integration:** The ingestion of real-time autonomous drone video feeds is reserved as a future scalability feature.
