from typing import Any, List
from pydantic import BaseModel


class GeoPoint(BaseModel):
    latitude: float
    longitude: float


class PlayablePath(BaseModel):
    id: str
    points: List[GeoPoint]


class ZoneSchema(BaseModel):
    zoneId: str
    name: str
    modeType: str
    difficulty: str
    estimatedDurationSeconds: int
    estimatedDistanceMeters: int
    boundary: List[GeoPoint]
    playerStartPoint: GeoPoint
    playablePaths: List[PlayablePath]
    buildings: List[Any] = []
    blockedRoads: List[Any] = []
    coins: List[Any] = []
    enemies: List[Any] = []
