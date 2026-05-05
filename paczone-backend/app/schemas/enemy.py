from typing import List
from pydantic import BaseModel
from app.schemas.zone import GeoPoint


class EnemySchema(BaseModel):
    id: str
    position: GeoPoint
    routePoints: List[GeoPoint]
    speedLevel: str    # "slow" | "normal" | "fast"
    behaviorType: str  # "patrol" | "chase"
