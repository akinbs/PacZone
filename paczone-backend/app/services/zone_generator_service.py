from typing import Optional
from app.schemas.location import LocationRequest
from app.schemas.zone import GeoPoint, PlayablePath, ZoneSchema
from app.utils.geo_math import offset_point
from app.utils.id_generator import new_zone_id, new_id


def generate_zone(request: LocationRequest, scenario: str) -> Optional[ZoneSchema]:
    if scenario not in ("success", "partial"):
        return None

    lat, lng = request.latitude, request.longitude
    radius = 40.0 if scenario == "partial" else 75.0

    # 4-corner boundary
    boundary = [
        _pt(lat, lng, radius, -radius),   # NW
        _pt(lat, lng, radius, radius),    # NE
        _pt(lat, lng, -radius, radius),   # SE
        _pt(lat, lng, -radius, -radius),  # SW
    ]

    if scenario == "partial":
        name, mode, diff, dur, dist = "Short PacZone", "short_run", "easy", 75, 160
    else:
        name, mode, diff, dur, dist = "Dynamic PacZone", "classic_run", "normal", 150, 420

    return ZoneSchema(
        zoneId=new_zone_id(),
        name=name,
        modeType=mode,
        difficulty=diff,
        estimatedDurationSeconds=dur,
        estimatedDistanceMeters=dist,
        boundary=boundary,
        playerStartPoint=GeoPoint(latitude=lat, longitude=lng),
        playablePaths=_build_paths(lat, lng, radius),
        buildings=[],
        blockedRoads=[],
        coins=[],
        enemies=[],
    )


def _pt(lat: float, lng: float, dn: float, de: float) -> GeoPoint:
    nlat, nlng = offset_point(lat, lng, dn, de)
    return GeoPoint(latitude=nlat, longitude=nlng)


def _build_paths(lat: float, lng: float, r: float) -> list[PlayablePath]:
    # Cross: horizontal + vertical through player position
    h = PlayablePath(
        id=new_id("path"),
        points=[_pt(lat, lng, 0, -r), _pt(lat, lng, 0, -r / 2),
                _pt(lat, lng, 0, 0),  _pt(lat, lng, 0, r / 2),
                _pt(lat, lng, 0, r)],
    )
    v = PlayablePath(
        id=new_id("path"),
        points=[_pt(lat, lng, -r, 0), _pt(lat, lng, -r / 2, 0),
                _pt(lat, lng, 0, 0),  _pt(lat, lng, r / 2, 0),
                _pt(lat, lng, r, 0)],
    )
    return [h, v]
