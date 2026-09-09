from unittest.mock import AsyncMock, patch
from uuid import UUID

import pytest

from app.services import agromonitoring_service as agro


@pytest.mark.asyncio
async def test_get_soil_data_correct_conversion_from_kelvin_to_celsius():
    with patch.object(agro, "_request", AsyncMock(return_value={"moisture": 0.3, "t0": 300.15, "t10": 295.15, "dt": 1000})):
        result = await agro.get_soil_data("polygon-1")
    assert result["moisture"] == 0.3
    assert result["surface_temp_c"] == 27.0
    assert result["depth_temp_c"] == 22.0
    assert result["source"] == "agromonitoring"
    assert result["observed_at"] == 1000


@pytest.mark.asyncio
async def test_get_weather_forecast_with_missing_optional_fields():
    current = {}
    forecast = []
    with patch.object(agro, "_request", AsyncMock(side_effect=[current, forecast])):
        result = await agro.get_weather_forecast(31.5, 74.3)

    assert result["current"]["temp_c"] is None
    assert result["current"]["humidity"] is None
    assert result["current"]["description"] is None
    assert result["forecast_days"] == []
    assert result["source"] == "agromonitoring"


@pytest.mark.asyncio
async def test_get_current_uvi_returns_expected_shape():
    with patch.object(agro, "_request", AsyncMock(return_value={"uvi": 5.2})):
        result = await agro.get_current_uvi("polygon-1")
    assert result == {"uvi": 5.2}


@pytest.mark.asyncio
async def test_get_forecast_uvi_returns_list():
    with patch.object(agro, "_request", AsyncMock(return_value=[{"uvi": 3.0}, {"uvi": 4.0}])):
        result = await agro.get_forecast_uvi("polygon-1")
    assert result == [{"uvi": 3.0}, {"uvi": 4.0}]


@pytest.mark.asyncio
async def test_get_index_statistics_with_missing_stats():
    scene = {"dc": 0, "cl": 100}
    result = await agro.get_index_statistics(scene, "ndvi")
    assert result is None


@pytest.mark.asyncio
async def test_get_index_statistics_with_non_dict_result():
    scene = {"stats": {"ndvi": "https://example.test/stats"}}
    with patch.object(agro, "_request", AsyncMock(return_value=[1, 2, 3])):
        result = await agro.get_index_statistics(scene, "ndvi")
    assert result is None


@pytest.mark.asyncio
async def test_create_polygon_fallback_on_400():
    geojson = {"type": "Feature", "geometry": {"type": "Polygon", "coordinates": []}}
    field_id = UUID("11111111-1111-1111-1111-111111111111")
    with patch.object(agro, "_request", AsyncMock(side_effect=[
        agro.AgroAPIError("bad request", status_code=400),
        [{"name": "Test · 11111111111111111111111111111111", "id": "poly-123"}],
    ])):
        result = await agro.create_polygon("Test", geojson, field_id)
        assert result == "poly-123"


@pytest.mark.asyncio
async def test_search_latest_scene_with_no_eligible_sentinel_images():
    images = [
        {"type": "l8", "dt": 100},
        {"type": "modis", "dt": 200},
    ]
    with patch.object(agro, "_request", AsyncMock(return_value=images)):
        result = await agro.search_latest_scene("polygon-1")
    assert result is None


@pytest.mark.asyncio
async def test_singleflight_with_exception_in_task():
    async def failing_factory():
        raise ValueError("test error")

    with pytest.raises(ValueError):
        await agro._singleflight("test-key", failing_factory)

    assert "test-key" not in agro._inflight

    async def success_factory():
        return "ok"

    result = await agro._singleflight("test-key", success_factory)
    assert result == "ok"
