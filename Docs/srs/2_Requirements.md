# 2. Functional & Non-Functional Requirements

## 2.1 Functional Requirements
The functional requirements define the core behaviors and capabilities of the AgriVision system. Based on the tri-source data architecture, the primary functional requirements are:

1.  **Multi-Modal AI Chatbot Interface:**
    *   The system must provide an interactive chat interface allowing farmers to ask natural language questions.
    *   The system must allow users to upload images (e.g., crop leaves) for visual disease diagnostics. The backend must enforce secure image sanitization, resize inputs, and strip EXIF metadata to protect user privacy.
    *   The chatbot must provide instant, synchronous responses to direct user queries.
2.  **Automated Satellite Data Ingestion:**
    *   The system must allow users to define field boundaries (polygons).
    *   The system must automatically retrieve Sentinel-2 satellite imagery, NDVI (Normalized Difference Vegetation Index) data, and soil profiles for registered fields.
    *   The system must fetch and display localized weather forecasts and UV indices.
3.  **Real-Time IoT Telemetry Aggregation:**
    *   The system must ingest real-time hardware sensor data (Temperature, Moisture, Humidity, pH, EC, NPK) via an MQTT bridge. The backend must enforce per-device rate limits and asynchronously batch-write readings to maximize ingestion throughput.
    *   The system must aggregate and store this telemetry mapped to specific farmer fields.
4.  **Asynchronous Field Recommendations:**
    *   The system must run background AI analysis on the combined field data (satellite + sensors) to generate actionable agronomic recommendations. If the AI provider fails, the system must generate deterministic fallback recommendations based on sensor telemetry.
5.  **Push Notification & Alert System:**
    *   The system must notify users asynchronously when long-running field analyses or recommendations are completed.
    *   The system must push immediate, critical emergency alerts to the user's device (even if the app is closed) if severe weather or critical sensor thresholds are breached.
6.  **User Authentication:**
    *   The system must provide secure user registration and login functionalities via Firebase Authentication.

## 2.2 Non-Functional Requirements
The non-functional requirements define the system's operational constraints, performance, and deployment strategy for the capstone presentation and future scalability.

1.  **Performance & Latency:**
    *   **Chatbot:** Must provide near-instantaneous replies to maintain a conversational user experience.
    *   **Background Processing:** Heavy AI recommendations and satellite data syncing must run asynchronously without blocking the user interface.
2.  **Deployment & Architecture (Version 1.0 - Capstone Presentation):**
    *   The primary presentation architecture will be hosted locally to ensure demonstration stability.
    *   The backend must be fully containerized using Docker, running on a local host machine.
    *   The frontend will be demonstrated via the Xcode iOS Simulator.
    *   IoT sensor data will be bridged locally via a physical USB-C serial connection to the host machine.
    *   External internet connectivity is strictly required *only* for third-party cloud APIs (Firebase, AgroMonitoring, Google Gemini).
3.  **Scalability & Cloud Readiness (Version 2.0):**
    *   While presented locally, the Dockerized FastAPI backend and MQTT architecture must be inherently designed for seamless migration to cloud infrastructure (e.g., AWS, Google Cloud) for the v2.0 production release.
4.  **Security:**
    *   All API endpoints must be secured using JWT (JSON Web Tokens) validated against the Firebase Authentication provider.
