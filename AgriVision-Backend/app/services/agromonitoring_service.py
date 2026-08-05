import asyncio
import hashlib
import json
import logging
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from uuid import UUID

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)
BASE_URL = "https://api.agromonitoring.com/agro/1.0"


class AgroAPIError(Exception):
    def __init__(self, message: str, status_code: int | None = None, retryable: bool = True) -> None:
        self.status_code = status_code
        self.retryable = retryable
        super().__init__(message)


class AgroEntitlementError(AgroAPIError):
    pass


_semaphore = asyncio.Semaphore(max(1, settings.AGRO_MAX_CONCURRENCY))
_inflight: dict[str, asyncio.Task] = {}
_inflight_lock = asyncio.Lock()
_circuit_open_until = 0.0
_failure_count = 0


def _log_request(endpoint: str, outcome: str, status_code: int | None, duration_ms: int, field_id: UUID | None = None, cache_hit: bool = False) -> None:
    try:
        from app.database import SessionLocal
        from app.models.db_models import ProviderRequestLog

        db = SessionLocal()
        try:
            db.add(ProviderRequestLog(provider="agromonitoring", endpoint=endpoint, field_id=field_id, outcome=outcome, status_code=status_code, duration_ms=duration_ms, cache_hit=cache_hit))
            db.commit()
        finally:
            db.close()
    except Exception:
        logger.debug("Unable to persist provider request telemetry", exc_info=True)


def _cache_get(cache_key: str) -> Any | None:
    try:
        from app.database import SessionLocal
        from app.models.db_models import ProviderCache

        db = SessionLocal()
        try:
            entry = db.query(ProviderCache).filter(ProviderCache.cache_key == cache_key, ProviderCache.expires_at > datetime.now(timezone.utc)).first()
            return entry.response_payload if entry else None
        finally:
            db.close()
    except Exception:
        logger.debug("Unable to read provider cache", exc_info=True)
        return None


def _cache_set(cache_key: str, endpoint: str, payload: Any, ttl_seconds: int, field_id: UUID | None) -> None:
    try:
        from app.database import SessionLocal
        from app.models.db_models import ProviderCache

        db = SessionLocal()
        try:
            entry = db.get(ProviderCache, cache_key)
            if entry is None:
                entry = ProviderCache(cache_key=cache_key, provider="agromonitoring", endpoint=endpoint, field_id=field_id, response_payload=payload, expires_at=datetime.now(timezone.utc) + timedelta(seconds=ttl_seconds))
                db.add(entry)
            else:
                entry.response_payload = payload
                entry.field_id = field_id
                entry.expires_at = datetime.now(timezone.utc) + timedelta(seconds=ttl_seconds)
            db.commit()
        finally:
            db.close()
    except Exception:
        logger.debug("Unable to persist provider cache", exc_info=True)


def _with_api_key(url: str) -> str:
    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query["appid"] = settings.AGROMONITORING_API_KEY
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


async def _singleflight(key: str, factory):
    async with _inflight_lock:
        task = _inflight.get(key)
        if task is None:
            task = asyncio.create_task(factory())
            _inflight[key] = task
    try:
        return await task
    finally:
        async with _inflight_lock:
            if _inflight.get(key) is task:
                _inflight.pop(key, None)


async def _request(
    method: str,
    endpoint: str,
    *,
    params: dict[str, Any] | None = None,
    json_body: dict[str, Any] | None = None,
    field_id: UUID | None = None,
    absolute_url: str | None = None,
    binary: bool = False,
    cache_ttl_seconds: int = 0,
):
    global _circuit_open_until, _failure_count
    if not settings.AGROMONITORING_API_KEY:
        raise AgroAPIError("AgroMonitoring is not configured", retryable=True)
    if time.monotonic() < _circuit_open_until:
        raise AgroAPIError("AgroMonitoring circuit is temporarily open", retryable=True)

    request_params: dict[str, Any] | None = dict(params or {})
    url = absolute_url or f"{BASE_URL}/{endpoint.lstrip('/')}"
    if absolute_url:
        url = _with_api_key(url)
        # Passing an empty params mapping to httpx replaces the query string
        # already present in provider-supplied image/statistics URLs.
        request_params = None
    else:
        request_params["appid"] = settings.AGROMONITORING_API_KEY
    key_material = json.dumps(
        {"method": method, "endpoint": endpoint, "params": request_params, "body": json_body, "url": absolute_url},
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    )
    key = hashlib.sha256(key_material.encode()).hexdigest()
    if method.upper() == "GET" and not binary and cache_ttl_seconds > 0:
        cached = await asyncio.to_thread(_cache_get, key)
        if cached is not None:
            _log_request(endpoint, "cache_hit", 200, 0, field_id, cache_hit=True)
            return cached

    async def perform():
        global _circuit_open_until, _failure_count
        start = time.monotonic()
        status_code = None
        async with _semaphore:
            for attempt in range(3):
                try:
                    async with httpx.AsyncClient(timeout=httpx.Timeout(20.0, connect=10.0), follow_redirects=True) as client:
                        response = await client.request(method, url, params=request_params, json=json_body)
                    status_code = response.status_code
                    if status_code in (401, 402, 403):
                        _log_request(endpoint, "denied", status_code, int((time.monotonic() - start) * 1000), field_id)
                        raise AgroEntitlementError("Endpoint is unavailable for this AgroMonitoring account", status_code, retryable=False)
                    if status_code == 429 or status_code >= 500:
                        if attempt < 2:
                            retry_after = response.headers.get("Retry-After")
                            delay = min(float(retry_after), 30.0) if retry_after and retry_after.replace(".", "", 1).isdigit() else 2 ** attempt
                            await asyncio.sleep(delay)
                            continue
                    response.raise_for_status()
                    _failure_count = 0
                    _log_request(endpoint, "success", status_code, int((time.monotonic() - start) * 1000), field_id)
                    if binary:
                        return response.content
                    if response.status_code == 204 or not response.content:
                        return {}
                    payload = response.json()
                    if method.upper() == "GET" and cache_ttl_seconds > 0:
                        await asyncio.to_thread(_cache_set, key, endpoint, payload, cache_ttl_seconds, field_id)
                    return payload
                except AgroEntitlementError:
                    raise
                except httpx.HTTPStatusError as exc:
                    if status_code is not None and 400 <= status_code < 500 and status_code != 429:
                        _log_request(endpoint, "rejected", status_code, int((time.monotonic() - start) * 1000), field_id)
                        raise AgroAPIError("AgroMonitoring rejected the request", status_code, retryable=False) from exc
                    if attempt == 2:
                        _failure_count += 1
                        if _failure_count >= 5:
                            _circuit_open_until = time.monotonic() + 300
                        _log_request(endpoint, "failure", status_code, int((time.monotonic() - start) * 1000), field_id)
                        raise AgroAPIError("AgroMonitoring request failed", status_code, retryable=True) from exc
                    await asyncio.sleep(2 ** attempt)
                except (httpx.HTTPError, ValueError) as exc:
                    if attempt == 2:
                        _failure_count += 1
                        if _failure_count >= 5:
                            _circuit_open_until = time.monotonic() + 300
                        _log_request(endpoint, "failure", status_code, int((time.monotonic() - start) * 1000), field_id)
                        raise AgroAPIError("AgroMonitoring request failed", status_code, retryable=True) from exc
                    await asyncio.sleep(2 ** attempt)
        raise AgroAPIError("AgroMonitoring request failed", status_code, retryable=True)

    return await _singleflight(key, perform)


def _provider_polygon_name(name: str, field_id: UUID | None) -> str:
    base = name.strip() or "AgriVision field"
    if field_id is None:
        return base[:100]
    # AgroMonitoring may reject duplicate polygon names. A field UUID makes the
    # provider identity unique even when one user gives multiple fields the same
    # display name, preventing a fallback lookup from reusing another boundary.
    suffix = f" · {field_id.hex}"
    return f"{base[:100 - len(suffix)]}{suffix}"


async def create_polygon(name: str, geojson: dict[str, Any], field_id: UUID | None = None) -> str:
    payload = {"name": _provider_polygon_name(name, field_id), "geo_json": geojson}
    try:
        data = await _request("POST", "polygons", json_body=payload, field_id=field_id)
        return data["id"]
    except AgroAPIError as exc:
        if exc.status_code != 400:
            raise
        polygons = await _request("GET", "polygons", field_id=field_id)
        match = next((item for item in polygons if item.get("name") == payload["name"]), None)
        if match:
            return match["id"]
        raise


async def delete_polygon(polygon_id: str, field_id: UUID | None = None) -> None:
    await _request("DELETE", f"polygons/{polygon_id}", field_id=field_id)


async def search_latest_scene(polygon_id: str, field_id: UUID | None = None) -> dict[str, Any] | None:
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=14)
    images = await _request(
        "GET",
        "image/search",
        params={
            "polyid": polygon_id,
            "start": int(start.timestamp()),
            "end": int(end.timestamp()),
            "type": "s2",
        },
        field_id=field_id,
        cache_ttl_seconds=3600,
    )
    eligible = [
        image
        for image in images
        if str(image.get("type", "")).lower() in {"s2", "sentinel 2", "sentinel-2", "sentinel2"}
    ]
    if not eligible:
        return None
    return max(eligible, key=lambda item: item.get("dt", 0))


async def get_index_statistics(scene: dict[str, Any], index: str, field_id: UUID | None = None) -> dict[str, Any] | None:
    url = (scene.get("stats") or {}).get(index.lower()) or (scene.get("stats") or {}).get(index.upper())
    if not url:
        return None
    result = await _request("GET", f"scene-stats-{index.lower()}", absolute_url=url, field_id=field_id, cache_ttl_seconds=30 * 86400)
    return result if isinstance(result, dict) else None


async def cache_scene_image(scene: dict[str, Any], index: str, field_id: UUID) -> str | None:
    images = scene.get("image") or {}
    aliases = {"truecolor": ("truecolor", "true_color"), "ndvi": ("ndvi",)}
    url = next((images.get(key) for key in aliases.get(index, (index,)) if images.get(key)), None)
    if not url:
        return None
    content = await _request("GET", f"scene-image-{index}", absolute_url=url, field_id=field_id, binary=True)
    root = settings.agro_media_path / str(field_id)
    root.mkdir(parents=True, exist_ok=True)
    acquired = str(scene.get("dt", "unknown"))
    path = root / f"{acquired}-{index}.png"
    path.write_bytes(content)
    return str(path)


async def get_soil_data(polygon_id: str, field_id: UUID | None = None) -> dict[str, Any]:
    data = await _request(
        "GET",
        "soil",
        params={"polyid": polygon_id},
        field_id=field_id,
        cache_ttl_seconds=settings.AGRO_SOIL_INTERVAL_HOURS * 3600,
    )
    return {
        "moisture": data.get("moisture"),
        "surface_temp_c": round(data["t0"] - 273.15, 1) if data.get("t0") is not None else None,
        "depth_temp_c": round(data["t10"] - 273.15, 1) if data.get("t10") is not None else None,
        "source": "agromonitoring",
        "observed_at": data.get("dt"),
    }


async def get_weather_forecast(lat: float, lon: float, field_id: UUID | None = None) -> dict[str, Any]:
    current, forecast = await asyncio.gather(
        _request(
            "GET",
            "weather",
            params={"lat": lat, "lon": lon, "units": "metric"},
            field_id=field_id,
            cache_ttl_seconds=settings.AGRO_WEATHER_INTERVAL_HOURS * 3600,
        ),
        _request(
            "GET",
            "weather/forecast",
            params={"lat": lat, "lon": lon, "units": "metric"},
            field_id=field_id,
            cache_ttl_seconds=settings.AGRO_WEATHER_INTERVAL_HOURS * 3600,
        ),
    )
    from collections import defaultdict

    daily = defaultdict(lambda: {"rain_mm": 0.0, "temps": [], "description": ""})
    forecast_entries = forecast if isinstance(forecast, list) else forecast.get("list", []) if isinstance(forecast, dict) else []
    for entry in forecast_entries:
        timestamp = entry.get("dt")
        day = datetime.fromtimestamp(timestamp, timezone.utc).date().isoformat() if timestamp else str(entry.get("dt_txt", ""))[:10]
        main = entry.get("main", {})
        if main.get("temp") is not None:
            daily[day]["temps"].append(main["temp"])
        daily[day]["rain_mm"] += (entry.get("rain") or {}).get("3h", 0.0)
        daily[day]["description"] = (entry.get("weather") or [{}])[0].get("description", "")
    days = [{
        "date": day,
        "temp_max_c": max(values["temps"]) if values["temps"] else None,
        "temp_min_c": min(values["temps"]) if values["temps"] else None,
        "rain_mm": round(values["rain_mm"], 1),
        "description": values["description"],
    } for day, values in sorted(daily.items())[:5]]
    main = current.get("main", {})
    return {
        "current": {
            "temp_c": main.get("temp"),
            "humidity": main.get("humidity"),
            "description": (current.get("weather") or [{}])[0].get("description"),
        },
        "forecast_days": days,
        "source": "agromonitoring",
    }


async def get_current_uvi(polygon_id: str, field_id: UUID | None = None) -> dict[str, Any]:
    return await _request(
        "GET",
        "uvi",
        params={"polyid": polygon_id},
        field_id=field_id,
        cache_ttl_seconds=settings.AGRO_UVI_INTERVAL_HOURS * 3600,
    )


async def get_forecast_uvi(polygon_id: str, field_id: UUID | None = None) -> dict[str, Any] | list[dict[str, Any]]:
    return await _request(
        "GET",
        "uvi/forecast",
        params={"polyid": polygon_id},
        field_id=field_id,
        cache_ttl_seconds=settings.AGRO_UVI_INTERVAL_HOURS * 3600,
    )


async def get_accumulated_temperature(lat: float, lon: float, start: int, end: int, field_id: UUID | None = None):
    return await _request("GET", "weather/history/accumulated_temperature", params={"lat": lat, "lon": lon, "start": start, "end": end, "threshold": 283.15}, field_id=field_id, cache_ttl_seconds=30 * 86400)


async def get_accumulated_precipitation(lat: float, lon: float, start: int, end: int, field_id: UUID | None = None):
    return await _request("GET", "weather/history/accumulated_precipitation", params={"lat": lat, "lon": lon, "start": start, "end": end}, field_id=field_id, cache_ttl_seconds=30 * 86400)


# Legacy name retained without using the paid historical NDVI endpoint.
async def get_ndvi_for_field(polygon_id: str) -> dict[str, Any] | None:
    scene = await search_latest_scene(polygon_id)
    if scene is None:
        return None
    stats = await get_index_statistics(scene, "ndvi")
    if not stats:
        return None
    return {"ndvi": stats.get("mean"), "source": "agromonitoring", "timestamp": scene.get("dt")}
