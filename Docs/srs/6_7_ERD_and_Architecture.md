# 6. Entity Relationship Diagram (ERD) & Database Design

To maintain clarity for the capstone presentation, this ERD focuses strictly on the core business entities that drive the AgriVision platform, omitting lower-level telemetry logging tables.

## 6.1 Core Database ERD
*Copy the code block below into Mermaid Live (mermaid.live) to generate the database diagram.*

```mermaid
erDiagram
    USER ||--o{ FIELD : "owns"
    USER ||--o{ SENSOR : "owns"
    FIELD ||--o{ SENSOR : "has"
    SENSOR ||--o{ SENSOR_READING : "generates"
    SENSOR ||--o{ SENSOR_READING_HOURLY : "generates"
    FIELD ||--o{ FIELD_OBSERVATION : "has"
    FIELD ||--o{ SATELLITE_SCENE : "has"
    FIELD ||--o{ AI_ANALYSIS_RUN : "has"
    FIELD ||--o{ FIELD_RECOMMENDATION : "receives"
    AI_ANALYSIS_RUN ||--o{ FIELD_RECOMMENDATION : "generates"
    FIELD ||--|| AI_CHAT_THREAD : "has"
    AI_CHAT_THREAD ||--o{ AI_CHAT_MESSAGE : "contains"
    FIELD ||--o{ AI_CHAT_MESSAGE : "contains"
    AI_CHAT_MESSAGE ||--o{ CHAT_ATTACHMENT : "has"
    FIELD ||--o{ CHAT_ATTACHMENT : "has"
    FIELD ||--o{ PROVIDER_CAPABILITY : "has"
    FIELD ||--o{ PROVIDER_REQUEST_LOG : "has"
    FIELD ||--o{ PROVIDER_CACHE : "has"

    USER {
        uuid id PK
        string firebase_uid
        string email
    }
    FIELD {
        uuid id PK
        uuid owner_id FK
        string name
        string crop_type
        geometry boundary
    }
    SENSOR {
        uuid id PK
        uuid owner_id FK
        uuid field_id FK
        string device_id
    }
    SENSOR_READING {
        datetime time PK
        uuid sensor_id FK
        float temperature
        float moisture
        float humidity
        float ph
        float ec
        float npk_n
    }
    FIELD_OBSERVATION {
        uuid id PK
        uuid field_id FK
        string source
        string metric
        float value
    }
    SATELLITE_SCENE {
        uuid id PK
        uuid field_id FK
        string provider_scene_id
    }
    AI_ANALYSIS_RUN {
        uuid id PK
        uuid field_id FK
        string status
    }
    FIELD_RECOMMENDATION {
        uuid id PK
        uuid field_id FK
        uuid analysis_run_id FK
        string category
        string advice
    }
    AI_CHAT_THREAD {
        uuid id PK
        uuid field_id FK
        text rolling_summary
    }
    AI_CHAT_MESSAGE {
        uuid id PK
        uuid field_id FK
        uuid thread_id FK
        string role
        text content
    }
    CHAT_ATTACHMENT {
        uuid id PK
        uuid field_id FK
        uuid message_id FK
        string storage_key
    }
    AGRONOMY_KNOWLEDGE_DOCUMENT {
        uuid id PK
        string external_id
        string title
        string crop
    }
```

---

# 7. Architecture Design Diagram

To comprehensively demonstrate the system to the evaluation panel, the architecture is broken down into two perspectives: High-Level Logical Flow and Low-Level Deployment.

## 7.1 High-Level Logical Architecture
This diagram illustrates how data flows between the primary actors, the backend core, and the external AI/Satellite APIs.

```mermaid
flowchart TD
    %% Actors
    Farmer([Farmer / iOS App])
    Sensor([ESP32 IoT Sensors])
    
    %% AgriVision Backend
    subgraph AgriVision Platform
        API[FastAPI Backend Core]
        AI[AI Advisor Service]
        MQTT[Mosquitto MQTT Broker]
        DB[(PostgreSQL + TimescaleDB)]
        Scheduler[Background Scheduler]
    end
    
    %% External Services
    subgraph External Cloud Services
        AgroAPI[AgroMonitoring API\n(Satellite & Weather)]
        Gemini[Google Gemini API\n(Vision & Text)]
        Vertex[Vertex AI Search\n(Punjab Agronomy DB)]
        Firebase[Firebase Auth]
        GCS[(Google Cloud Storage\nMedia Backup)]
    end
    
    %% Connections
    Farmer -- HTTP / REST --> API
    Farmer -- Authenticates --> Firebase
    Sensor -- Serial / MQTT --> MQTT
    MQTT -- Ingests Telemetry --> API
    
    API -- Read / Write --> DB
    API -- Fetch Imagery --> AgroAPI
    API -- Delegates Logic --> AI
    API -- Uploads Chat Images --> GCS
    
    Scheduler -- Triggers Field Sync --> API
    Scheduler -- Polls Satellite Data --> AgroAPI
    Scheduler -- Generates Background Insights --> AI
    
    AI -- RAG Document Retrieval --> Vertex
    AI -- Generates Insights --> Gemini
```

## 7.2 Low-Level Deployment Architecture (v1.0 Capstone)
This diagram illustrates exactly how the software components are deployed and isolated on the local host machine for the final presentation.

```mermaid
flowchart LR
    subgraph Mac_Host [Local Host Machine (macOS)]
        direction TB
        
        subgraph Docker_Network [Docker Compose Bridge]
            App[FastAPI Container\nPort 8000]
            DB[(PostgreSQL Container\nPort 5432)]
            Broker[Mosquitto Container\nPort 1883]
            
            App --- DB
            App --- Broker
        end
        
        Simulator[Xcode iOS Simulator]
        SerialBridge[Python Serial-to-MQTT Bridge]
        LocalMedia[Local File System\n(PrivateMediaStorage)]
    end
    
    Hardware[Physical ESP32 Board]
    Cloud((External Internet APIs\nFirebase, GCS, AgroMonitoring))
    
    %% Connections
    Hardware -- USB-C / Serial Cable --> SerialBridge
    SerialBridge -- Publishes Data --> Broker
    Simulator -- Localhost REST API --> App
    App -- Read / Write Images --> LocalMedia
    App -- HTTPS Outbound --> Cloud
```
