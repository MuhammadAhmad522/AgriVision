import time
from unittest.mock import patch

import pytest

from app.core.errors import APIError
from app.core.rate_limit import InMemoryRateLimiter


@pytest.mark.asyncio
async def test_accepts_request_under_limit():
    limiter = InMemoryRateLimiter()
    for _ in range(3):
        await limiter.check("test-key", limit=5, window_seconds=60)


@pytest.mark.asyncio
async def test_rejects_request_over_limit():
    limiter = InMemoryRateLimiter()
    for _ in range(5):
        await limiter.check("test-key", limit=5, window_seconds=60)
    with pytest.raises(APIError) as raised:
        await limiter.check("test-key", limit=5, window_seconds=60)
    assert raised.value.status_code == 429
    assert raised.value.code == "rate_limited"


@pytest.mark.asyncio
async def test_different_keys_dont_interfere():
    limiter = InMemoryRateLimiter()
    for _ in range(5):
        await limiter.check("key-a", limit=5, window_seconds=60)
    for _ in range(5):
        await limiter.check("key-b", limit=5, window_seconds=60)


@pytest.mark.asyncio
async def test_window_expiry_resets_counter():
    limiter = InMemoryRateLimiter()
    for _ in range(5):
        await limiter.check("test-key", limit=5, window_seconds=60)

    future = time.monotonic() + 61
    with patch("app.core.rate_limit.time.monotonic", return_value=future):
        await limiter.check("test-key", limit=5, window_seconds=60)


@pytest.mark.asyncio
async def test_retryable_flag_is_set():
    limiter = InMemoryRateLimiter()
    for _ in range(5):
        await limiter.check("test-key", limit=5, window_seconds=60)
    with pytest.raises(APIError) as raised:
        await limiter.check("test-key", limit=5, window_seconds=60)
    assert raised.value.retryable is True
