---
name: generate-documentation
description: >-
  Use this skill when asked to generate, audit, or create comprehensive project documentation, software requirements, or architecture diagrams for a codebase.
---

# Generate Documentation Skill

Follow these steps when asked to generate or audit project documentation:

## 1. Deep Codebase Audit
- Scan the root directory to identify all sub-projects (e.g., Web, iOS, Backend, IoT).
- Read the package manager files (`package.json`, `requirements.txt`, `platformio.ini`, `Podfile`, `.pbxproj`) to understand the complete technology stack.
- Review infrastructure files (`docker-compose.yml`, `Dockerfile`, `.env`) to document orchestration and external APIs.
- Examine database models (e.g., SQLAlchemy `db_models.py`) and validation schemas (e.g., Pydantic `pydantic_schemas.py`) to build an accurate Data Dictionary and ERD.

## 2. Identify Core Flows
- Trace the frontend UI views down to the backend API routers to map out the user lifecycle and core functional requirements.
- Identify background jobs, cron tasks, or hardware ingestion pipelines (e.g., MQTT, background workers).

## 3. Generate the Documentation
- Always use the `artifacts` system to present the documentation.
- When generating diagrams using Mermaid, you MUST strictly adhere to these fail-safe rules:
  - **Flowcharts**: Wrap all Node labels and Subgraph labels in double quotes inside brackets (e.g., `["React App"]`, `[("PostgreSQL")]`).
  - **Sequence Diagrams**: Strip out all parentheses, `+`, `_`, and special characters from `participant` aliases, messages, and `Note` blocks.
  - **ERD/Class Diagrams**: Keep property definitions simple and standard.
- Ensure the document includes an Executive Summary, Tech Stack, Functional Requirements, DB Schema, and Architecture/Sequence Diagrams.
