from fastapi import APIRouter
from app.api.routes import health, dynamic_zones

api_router = APIRouter()
api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(dynamic_zones.router, prefix="/dynamic-zones", tags=["dynamic-zones"])
