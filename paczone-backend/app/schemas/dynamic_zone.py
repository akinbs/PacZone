from typing import Optional
from pydantic import BaseModel
from app.schemas.zone import ZoneSchema


class AnalyzeResponse(BaseModel):
    playable: bool
    status: str
    playabilityScore: int
    reason: Optional[str] = None
    suggestion: Optional[str] = None
    zone: Optional[ZoneSchema] = None
