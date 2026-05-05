from typing import Optional
from app.schemas.dynamic_zone import AnalyzeResponse

# In-memory cache placeholder — replace with Redis in production.
_cache: dict[str, AnalyzeResponse] = {}


def get(key: str) -> Optional[AnalyzeResponse]:
    return _cache.get(key)


def set(key: str, value: AnalyzeResponse) -> None:
    _cache[key] = value


def clear() -> None:
    _cache.clear()
