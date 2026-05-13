# Graph Report - AgriVision-Backend  (2026-05-04)

## Corpus Check
- 21 files · ~7,235 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 131 nodes · 163 edges · 11 communities detected
- Extraction: 82% EXTRACTED · 18% INFERRED · 0% AMBIGUOUS · INFERRED: 30 edges (avg confidence: 0.67)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b52ffbce`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]

## God Nodes (most connected - your core abstractions)
1. `BaseModel` - 12 edges
2. `FieldRecommendation` - 8 edges
3. `run_ai_for_field()` - 8 edges
4. `Field` - 7 edges
5. `AIChatMessage` - 7 edges
6. `Base` - 6 edges
7. `RecommendationFeedback` - 6 edges
8. `lifespan()` - 5 edges
9. `create_field()` - 5 edges
10. `ChatMessageRequest` - 5 edges

## Surprising Connections (you probably didn't know these)
- `lifespan()` --calls--> `run_in_background()`  [INFERRED]
  app/main.py → app/services/mqtt_service.py
- `get_current_user()` --calls--> `User`  [INFERRED]
  app/core/auth.py → app/models/db_models.py
- `create_field()` --calls--> `Field`  [INFERRED]
  app/api/fields.py → app/models/db_models.py
- `create_field()` --calls--> `Sensor`  [INFERRED]
  app/api/fields.py → app/models/db_models.py
- `run_ai_for_field()` --calls--> `FieldRecommendation`  [INFERRED]
  app/services/scheduler.py → app/models/db_models.py

## Communities (19 total, 3 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.08
Nodes (23): get_accumulated_precipitation(), get_accumulated_temperature(), get_current_uvi(), get_forecast_uvi(), get_historical_soil(), get_historical_uvi(), get_historical_weather(), get_ndvi_for_field() (+15 more)

### Community 1 - "Community 1"
Cohesion: 0.18
Nodes (19): ChatMessageRequest, ChatMessageResponse, Config, get_chat_history(), post_chat_message(), Fetch the chat history for a field., Send a message to the AI Advisor, returning its contextual response., RecommendationFeedback (+11 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (14): lifespan(), Handles startup and shutdown events.     - On startup: creates DB tables and sta, create_polygon(), Registers a new field polygon with the Agromonitoring API.     Returns the `poly, ai_reasoning_loop(), Periodic background task that fetches satellite NDVI and soil data      for all, Periodic background task that runs the AI advisor for all fields.     Executes e, Starts the satellite sync loop in the background. (+6 more)

### Community 3 - "Community 3"
Cohesion: 0.3
Nodes (11): BaseModel, FieldCreate, FieldResponse, FieldWithSensorsCreate, PointCoordinates, RecommendationResponse, SensorCreate, SensorReadingBase (+3 more)

### Community 4 - "Community 4"
Cohesion: 0.2
Nodes (10): coordinates_to_wkt(), create_field(), delete_field(), get_field(), get_fields(), Get a specific field by ID., Delete a field by ID., Convert a list of PointCoordinates to a WKT POLYGON string. (+2 more)

### Community 5 - "Community 5"
Cohesion: 0.24
Nodes (9): _build_field_context(), chat_with_advisor(), generate_field_recommendations(), _generate_rule_based_recommendations(), AI Advisor Service — The "Brain" of AgriVision  This service aggregates multi-mo, Core AI reasoning function. Assembles field context and calls Gemini     to gene, Allows the user to chat directly with the AI, bringing in full field context and, Deterministic fallback recommendations based on threshold rules.     Used when G (+1 more)

### Community 6 - "Community 6"
Cohesion: 0.25
Nodes (7): get_recommendations(), Recommendations API Endpoints  Serves stored AI-generated agronomic recommendati, Trigger an immediate AI analysis for a specific field.     This runs the full da, Get the latest AI-generated recommendations for a specific field.     Returns th, Allow the farmer to provide feedback (e.g. 'implemented', 'ignored') on a recomm, trigger_recommendation_refresh(), update_recommendation_feedback()

### Community 7 - "Community 7"
Cohesion: 0.33
Nodes (4): Launch MQTT bridge in a daemon thread so it doesn't block FastAPI startup., Start the MQTT client in a background thread., run_in_background(), start_mqtt_bridge()

## Knowledge Gaps
- **43 isolated node(s):** `Handles startup and shutdown events.     - On startup: creates DB tables and sta`, `Decodes the Firebase JWT from the 'Authorization: Bearer <TOKEN>' header.     If`, `BaseSettings`, `Stores AI-generated agronomic recommendations for each field.     Populated by t`, `Stores conversational memory for the autonomous AI agent.     Roles: 'user' or '` (+38 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `run_ai_for_field()` connect `Community 2` to `Community 0`, `Community 1`, `Community 5`, `Community 6`?**
  _High betweenness centrality (0.383) - this node is a cross-community bridge._
- **Why does `FieldRecommendation` connect `Community 1` to `Community 2`?**
  _High betweenness centrality (0.275) - this node is a cross-community bridge._
- **Why does `create_field()` connect `Community 4` to `Community 1`?**
  _High betweenness centrality (0.126) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `FieldRecommendation` (e.g. with `run_ai_for_field()` and `RecommendationFeedback`) actually correct?**
  _`FieldRecommendation` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `run_ai_for_field()` (e.g. with `trigger_recommendation_refresh()` and `get_soil_data()`) actually correct?**
  _`run_ai_for_field()` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `Field` (e.g. with `create_field()` and `RecommendationFeedback`) actually correct?**
  _`Field` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `AIChatMessage` (e.g. with `post_chat_message()` and `ChatMessageRequest`) actually correct?**
  _`AIChatMessage` has 4 INFERRED edges - model-reasoned connections that need verification._