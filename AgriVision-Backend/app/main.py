import asyncio
import logging
import re
import uuid
from contextlib import asynccontextmanager

import firebase_admin
from alembic import command
from alembic.config import Config
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from firebase_admin import credentials
from sqlalchemy import text

from app.api import chat, export, fields, recommendations, satellite, sensors, session, invitations
from app.core.config import settings
from app.core.errors import APIError, error_payload
from app.database import engine
from app.services.mqtt_service import start_background_tasks

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger(__name__)


def _initialize_firebase() -> None:
    try:
        firebase_admin.get_app()
        return
    except ValueError:
        pass
    try:
        firebase_admin.initialize_app(credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH))
        logger.info("Firebase Admin initialized")
    except Exception as exc:
        # Authentication stays fail-closed in get_current_user.
        logger.error("Firebase Admin initialization failed: %s", type(exc).__name__)


def _prepare_database() -> None:
    with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
        connection.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
        if settings.ENABLE_TIMESCALEDB:
            connection.execute(text("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"))
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)
    command.upgrade(config, "head")
    if settings.ENABLE_TIMESCALEDB:
        with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
            connection.execute(
                text(
                    "SELECT create_hypertable("
                    "'sensor_readings', 'time', "
                    "if_not_exists => TRUE, migrate_data => TRUE"
                    ")"
                )
            )


@asynccontextmanager
async def lifespan(app: FastAPI):
    _initialize_firebase()
    for attempt in range(5):
        try:
            await asyncio.to_thread(_prepare_database)
            break
        except Exception:
            if attempt == 4:
                raise
            logger.warning("Database is not ready; retrying (%s/5)", attempt + 1)
            await asyncio.sleep(3)

    from app.services.scheduler import start_ai_reasoning_worker, start_satellite_sync_worker, _aggregation_loop

    mqtt_consumer = await start_background_tasks()
    tasks = [start_satellite_sync_worker(), start_ai_reasoning_worker(), asyncio.create_task(_aggregation_loop()), mqtt_consumer]
    yield
    for task in tasks:
        task.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)


app = FastAPI(title=settings.PROJECT_NAME, version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins if settings.allowed_origins else ["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def request_context(request: Request, call_next):
    supplied_request_id = request.headers.get("X-Request-ID", "")
    request_id = supplied_request_id if re.fullmatch(r"[A-Za-z0-9._:-]{1,100}", supplied_request_id) else str(uuid.uuid4())
    request.state.request_id = request_id
    content_length = request.headers.get("Content-Length")
    is_chat_upload = request.method == "POST" and request.url.path.endswith("/chat") and request.headers.get("Content-Type", "").startswith("multipart/form-data")
    request_limit = settings.CHAT_REQUEST_MAX_BYTES if is_chat_upload else settings.MAX_REQUEST_BODY_BYTES
    if content_length and content_length.isdigit() and int(content_length) > request_limit:
        error = APIError(413, "payload_too_large", "The submitted request is too large.")
        response = JSONResponse(status_code=413, content=error_payload(error, request_id))
    else:
        response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Cache-Control"] = "no-store"
    return response


@app.exception_handler(APIError)
async def api_error_handler(request: Request, exc: APIError):
    return JSONResponse(status_code=exc.status_code, content=error_payload(exc, request.state.request_id), headers=exc.headers)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    details = [{"field": ".".join(str(part) for part in item["loc"] if part != "body"), "message": item["msg"]} for item in exc.errors()]
    error = APIError(422, "validation_failed", "Some submitted values are invalid.", details=details)
    return JSONResponse(status_code=422, content=error_payload(error, request.state.request_id))


@app.exception_handler(HTTPException)
async def http_error_handler(request: Request, exc: HTTPException):
    error = APIError(exc.status_code, "request_failed", str(exc.detail), retryable=exc.status_code >= 500)
    return JSONResponse(status_code=exc.status_code, content=error_payload(error, request.state.request_id), headers=exc.headers)


@app.exception_handler(Exception)
async def unhandled_error_handler(request: Request, exc: Exception):
    logger.exception("Unhandled request failure request_id=%s", request.state.request_id)
    error = APIError(500, "internal_error", "The server could not complete this request.", retryable=True)
    return JSONResponse(status_code=500, content=error_payload(error, request.state.request_id))


from app.api import chat, export, fields, recommendations, satellite, sensors, session, invitations, admin

# ... (rest of imports are fine, but since we are just replacing line 139-140) ...

for router in (session.router, fields.router, sensors.router, recommendations.router, chat.router, satellite.router, export.router, invitations.router, admin.router):
    app.include_router(router)


@app.get("/")
def root():
    return {"message": "AgriVision API is online"}


@app.get("/health")
def health():
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
    try:
        firebase_admin.get_app()
        auth_status = "ready"
    except ValueError:
        auth_status = "unavailable"
    return {"status": "healthy", "version": "1.0.0", "authentication": auth_status}
