# 8. Sequence Diagrams

To demonstrate the dynamic interactions between the components of the AgriVision system, the four most critical processes are modeled below.

*You can copy the code blocks below and paste them into Mermaid Live (mermaid.live) to generate the visual sequence diagrams.*

## 8.1 Field Creation & Satellite Sync
This flow demonstrates how a user establishes a field boundary and how the backend asynchronously pulls initial satellite data to prevent UI blocking.

```mermaid
sequenceDiagram
    participant User as iOS Client
    participant API as FastAPI Backend
    participant Worker as Background Task
    participant Agro as AgroMonitoring API
    participant DB as PostgreSQL DB

    User->>API: POST /api/fields (GeoJSON Polygon)
    API->>Agro: POST /polygons
    Agro-->>API: Returns Polygon ID
    API->>DB: Save Field with Polygon ID
    API-->>User: 201 Created (Field ID)
    
    API->>Worker: Trigger sync_field_background & run_ai_by_field_id
    activate Worker
    Worker->>Agro: Fetch NDVI & Weather
    Agro-->>Worker: Return Statistics
    Worker->>DB: Update Field Profile
    Worker->>Worker: Generate Initial Field Insights
    deactivate Worker
```

## 8.2 AI Image Upload & Diagnosis
This flow demonstrates the multi-modal AI capabilities, highlighting the Retrieval-Augmented Generation (RAG) and the strict safety guardrails.

```mermaid
sequenceDiagram
    participant User as iOS Client
    participant API as FastAPI Backend
    participant Vertex as Vertex AI Search
    participant Gemini as Google Gemini
    
    User->>API: POST /chat (Image bytes + Text)
    API->>API: Sanitize, strip EXIF, and resize image
    API->>Vertex: Retrieve agricultural guidelines (RAG)
    Vertex-->>API: Return grounded documents
    API->>Gemini: Send Prompt + Image + RAG Docs
    Gemini-->>API: Return diagnostic JSON
    API->>API: Apply safety guardrails (Check pesticide terms)
    API-->>User: Return safe, grounded chat response
```

## 8.3 IoT Sensor Telemetry Ingestion
This flow shows how continuous physical ground data makes its way into the backend database.

```mermaid
sequenceDiagram
    participant ESP32 as Physical IoT Node
    participant Bridge as Python Serial Bridge
    participant MQTT as Mosquitto Broker
    participant API as FastAPI Aggregator
    participant DB as TimescaleDB
    
    loop Every 30 seconds
        ESP32->>Bridge: USB Serial Telemetry (JSON)
        Bridge->>MQTT: Publish to agrivision/sensors/{id}
        MQTT->>API: Fast path enqueue reading
    end
    loop Background Async Queue (batch = 50)
        API->>DB: _db_writer_loop Batch Insert (Non-blocking)
    end
```

## 8.4 User Registration & Authentication
This flow outlines the secure, token-based authentication mechanism using Firebase.

```mermaid
sequenceDiagram
    participant User as iOS Client
    participant Firebase as Firebase Auth
    participant API as FastAPI Backend
    
    User->>Firebase: Login with Email/Pass or Google
    Firebase-->>User: Return JWT ID Token
    User->>API: Send secure request with Bearer Token
    API->>Firebase: Verify Token Cryptographic Signature
    Firebase-->>API: Token Valid (Returns User UID)
    API-->>User: 200 OK (Protected Data returned)
```

## 8.5 Automated AI Reasoning Loop
This flow demonstrates the background scheduler that wakes up periodically to run AI evaluations across all fields.

```mermaid
sequenceDiagram
    participant Scheduler as ai_reasoning_loop
    participant DB as TimescaleDB
    participant AI as Gemini AI Provider
    
    loop Every 5 minutes
        Scheduler->>DB: Fetch Active Fields
        Scheduler->>DB: Fetch Sensor Readings & Satellite Data
        Scheduler->>AI: Send Fingerprinted Context
        AI-->>Scheduler: Return Agronomic Insights
        Scheduler->>DB: Save FieldRecommendations
    end
```

---

# 9. Class Diagram

This hybrid class diagram bridges the gap between the iOS client architecture (MVVM-C) and the Python backend structure. It highlights how frontend `ViewModels` map to backend `Services` and database `Entities`.

```mermaid
classDiagram
    %% iOS Client Classes
    namespace iOS_Frontend {
        class DashboardFeature {
            <<ViewModel>>
            +fetchFieldData()
        }
        class AIChatFeature {
            <<ViewModel>>
            +sendMessage()
        }
        class SensorIntegrationFeature {
            <<ViewModel>>
            +pairDevice()
        }
        class FieldsFeature {
            <<ViewModel>>
            +drawPolygon()
        }
    }
    
    %% Backend Services
    namespace FastAPI_Backend_Services {
        class AgromonitoringService {
            +create_polygon(geojson)
        }
        class AIAdvisorService {
            +chat_with_advisor(msg, images, context)
        }
        class MQTTService {
            +_db_writer_loop()
        }
        class SchedulerService {
            +ai_reasoning_loop()
            +external_data_loop()
        }
    }
    
    %% DB Models
    namespace Database_Entities {
        class Field {
            +UUID id
            +String name
            +JSON boundary
        }
        class SensorReading {
            +DateTime time
            +Float temperature
            +Float moisture
        }
    }
    
    %% Relationships across the network boundary
    DashboardFeature ..> AgromonitoringService : HTTP REST JSON
    AIChatFeature ..> AIAdvisorService : HTTP REST JSON
    
    %% Backend internal relationships
    AgromonitoringService --> Field : Updates Profile
    MQTTService --> SensorReading : Inserts Telemetry
    SchedulerService --> AIAdvisorService : Triggers RAG
    AIAdvisorService --> Field : Reads Context
```
