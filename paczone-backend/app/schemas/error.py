from typing import Any, Dict
from pydantic import BaseModel


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: Dict[str, Any] = {}


class ErrorResponse(BaseModel):
    error: ErrorDetail
