from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, field_validator

_VALID_SCENARIOS = {"success", "partial", "failed", "gpsWeak", "speedTooHigh", "noData"}


class LocationRequest(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    accuracy: float = Field(..., gt=0.0, description="GPS accuracy in meters")
    heading: Optional[float] = Field(None, ge=0.0, lt=360.0)
    speed: float = Field(0.0, ge=0.0, description="Speed in m/s")
    timestamp: Optional[datetime] = None
    scanSizeMeters: int = Field(150, ge=80, le=250)
    debugScenario: Optional[str] = Field(
        None,
        description="Dev-only: forces a specific response scenario",
    )

    @field_validator("debugScenario")
    @classmethod
    def validate_debug_scenario(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in _VALID_SCENARIOS:
            raise ValueError(f"debugScenario must be one of {_VALID_SCENARIOS}")
        return v
