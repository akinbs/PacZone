from pydantic import BaseModel
from app.schemas.zone import GeoPoint


class CoinSchema(BaseModel):
    id: str
    position: GeoPoint
    type: str   # "normal" | "power"
    value: int
