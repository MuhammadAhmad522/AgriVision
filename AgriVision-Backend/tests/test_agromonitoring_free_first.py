import asyncio
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch
from uuid import UUID

import httpx
import pytest
from urllib.parse import parse_qs, urlsplit

from app.services import agromonitoring_service as agro


@pytest.mark.asyncio
async def test_polygon_provider_names_are_unique_per_field_even_with_same_display_name():
    first_id = UUID("11111111-1111-1111-1111-111111111111")
    second_id = UUID("22222222-2222-2222-2222-222222222222")
    geojson = {"type": "Feature", "geometry": {"type": "Polygon", "coordinates": []}}
    with patch.object(agro, "_request", AsyncMock(side_effect=[{"id": "poly-1"}, {"id": "poly-2"}])) as request:
        assert await agro.create_polygon("North Field", geojson, first_id) == "poly-1"
        assert await agro.create_polygon("North Field", geojson, second_id) == "poly-2"

    first_name = request.await_args_list[0].kwargs["json_body"]["name"]
    second_name = request.await_args_list[1].kwargs["json_body"]["name"]
    assert first_name != second_name
    assert first_id.hex in first_name
    assert second_id.hex in second_name
    assert len(first_name) <= 100
    assert len(second_name) <= 100


@pytest.mark.asyncio
async def test_satellite_search_uses_recent_unfiltered_sentinel_scenes():
    older = {"dt": 100, "type": "s2", "cl": 99, "dc": 1}
    newer = {"dt": 200, "type": "Sentinel 2", "cl": 100, "dc": 0}
    with patch.object(agro, "_request", AsyncMock(return_value=[older, newer])) as request:
        result = await agro.search_latest_scene("polygon-1")

    assert result == newer
    kwargs = request.await_args.kwargs
    assert request.await_args.args[:2] == ("GET", "image/search")
    assert kwargs["params"]["type"] == "s2"
    assert "coverage_min" not in kwargs["params"]
    assert "clouds_max" not in kwargs["params"]
    assert 13.9 * 86400 <= kwargs["params"]["end"] - kwargs["params"]["start"] <= 14.1 * 86400
    assert kwargs["cache_ttl_seconds"] == 3600


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "forecast",
    [
        [{"dt": 1_700_000_000, "main": {"temp": 20}, "weather": [{"description": "clear"}]}],
        {"list": [{"dt": 1_700_000_000, "main": {"temp": 20}, "weather": [{"description": "clear"}]}]},
    ],
)
async def test_weather_forecast_accepts_list_and_wrapped_list(forecast):
    current = {"main": {"temp": 21, "humidity": 60}, "weather": [{"description": "sunny"}]}
    with patch.object(agro, "_request", AsyncMock(side_effect=[current, forecast])):
        result = await agro.get_weather_forecast(31.5, 74.3)

    assert result["current"] == {"temp_c": 21, "humidity": 60, "description": "sunny"}
    assert result["forecast_days"][0]["temp_max_c"] == 20
    assert result["forecast_days"][0]["description"] == "clear"


@pytest.mark.asyncio
async def test_initial_sync_timeout_returns_false_and_cancels_work():
    from app.services import scheduler

    cancelled = False

    async def slow_sync(*args, **kwargs):
        nonlocal cancelled
        try:
            await asyncio.sleep(1)
        except asyncio.CancelledError:
            cancelled = True
            raise

    with patch.object(scheduler, "sync_field_once", side_effect=slow_sync):
        completed = await scheduler.sync_field_initial("field-id", timeout_seconds=0.01)

    assert completed is False
    assert cancelled is True


@pytest.mark.asyncio
async def test_singleflight_coalesces_duplicate_requests():
    calls = 0

    async def factory():
        nonlocal calls
        calls += 1
        await asyncio.sleep(0.01)
        return {"ok": True}

    first, second = await asyncio.gather(
        agro._singleflight("same-key", factory),
        agro._singleflight("same-key", factory),
    )
    assert first == second == {"ok": True}
    assert calls == 1


@pytest.fixture
def mock_http_client():
    mock = AsyncMock(spec=httpx.AsyncClient)
    mock_request = AsyncMock(return_value=httpx.Response(200, json={"ok": True}))
    mock.__aenter__.return_value = mock
    mock.request = mock_request
    with patch.object(agro.httpx, "AsyncClient", return_value=mock):
        yield mock_request


@pytest.mark.asyncio
async def test_provider_absolute_urls_keep_api_key_query_string(mock_http_client):
    mock_http_client.return_value = httpx.Response(200, json={"mean": 0.5}, request=httpx.Request("GET", "https://example.test"))
    with (
        patch.object(agro.settings, "AGROMONITORING_API_KEY", "test-key"),
        patch.object(agro, "_log_request"),
    ):
        await agro._request("GET", "scene-stats", absolute_url="http://api.agromonitoring.test/stats/1.0/example?appid=old")

    sent_url = mock_http_client.call_args[0][1]
    assert parse_qs(urlsplit(sent_url).query)["appid"] == ["test-key"]
    assert mock_http_client.call_args[1]["params"] is None


@pytest.mark.asyncio
async def test_no_content_delete_is_successful_without_json_decode_retry(mock_http_client):
    mock_http_client.return_value = httpx.Response(204, request=httpx.Request("DELETE", "https://example.test"))
    with (
        patch.object(agro.settings, "AGROMONITORING_API_KEY", "test-key"),
        patch.object(agro, "_log_request"),
    ):
        await agro.delete_polygon("polygon-1")
    mock_http_client.assert_called_once()


@pytest.mark.asyncio
async def test_entitlement_denial_is_non_retryable_and_not_retried(mock_http_client):
    mock_http_client.return_value = httpx.Response(402, request=httpx.Request("GET", "https://example.test"))
    with (
        patch.object(agro.settings, "AGROMONITORING_API_KEY", "test-key"),
        patch.object(agro, "_log_request"),
    ):
        with pytest.raises(agro.AgroEntitlementError) as raised:
            await agro.get_accumulated_temperature(31.5, 74.3, 1, 2)
    assert raised.value.retryable is False
    mock_http_client.assert_called_once()


@pytest.mark.asyncio
async def test_bad_provider_request_is_not_retried(mock_http_client):
    mock_http_client.return_value = httpx.Response(400, request=httpx.Request("POST", "https://example.test"))
    with (
        patch.object(agro.settings, "AGROMONITORING_API_KEY", "test-key"),
        patch.object(agro, "_log_request"),
    ):
        with pytest.raises(agro.AgroAPIError) as raised:
            await agro._request("POST", "polygons", json_body={"name": "invalid"})
    assert raised.value.retryable is False
    mock_http_client.assert_called_once()


def test_free_mode_default_and_no_historical_ndvi_endpoint():
    assert agro.settings.AGRO_FREE_MODE is True
    import inspect

    source = inspect.getsource(agro.get_ndvi_for_field)
    assert "history/ndvi" not in source
    assert "search_latest_scene" in source
