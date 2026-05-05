from fastapi import APIRouter
from app.schemas.location import LocationRequest
from app.schemas.dynamic_zone import AnalyzeResponse
from app.services import scan_decision_service

router = APIRouter()


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze_zone(request: LocationRequest) -> AnalyzeResponse:
    return scan_decision_service.analyze(request)
