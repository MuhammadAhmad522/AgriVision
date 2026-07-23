import asyncio
import time
from collections import defaultdict, deque

from app.core.errors import APIError


class InMemoryRateLimiter:
    """Small local limiter. Replace with Redis when running multiple API replicas."""

    def __init__(self) -> None:
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = asyncio.Lock()

    async def check(self, key: str, limit: int, window_seconds: int) -> None:
        now = time.monotonic()
        async with self._lock:
            events = self._events[key]
            while events and events[0] <= now - window_seconds:
                events.popleft()
            if len(events) >= limit:
                raise APIError(429, "rate_limited", "Too many requests. Please wait and try again.", retryable=True)
            events.append(now)


rate_limiter = InMemoryRateLimiter()
