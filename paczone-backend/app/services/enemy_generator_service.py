from typing import List
from app.schemas.enemy import EnemySchema
from app.schemas.location import LocationRequest
from app.schemas.zone import GeoPoint
from app.utils.geo_math import offset_point
from app.utils.id_generator import new_id

_SPAWN_OFFSETS: list[tuple[float, float]] = [(60, 40), (-60, -40)]


def generate_enemies(request: LocationRequest, count: int = 1) -> List[EnemySchema]:
    lat, lng = request.latitude, request.longitude
    enemies: List[EnemySchema] = []

    for dn, de in _SPAWN_OFFSETS[:count]:
        o_lat, o_lng = offset_point(lat, lng, dn, de)
        e_lat, e_lng = offset_point(lat, lng, dn + 20, de + 20)
        enemies.append(EnemySchema(
            id=new_id("enemy"),
            position=GeoPoint(latitude=o_lat, longitude=o_lng),
            routePoints=[
                GeoPoint(latitude=o_lat, longitude=o_lng),
                GeoPoint(latitude=e_lat, longitude=e_lng),
                GeoPoint(latitude=o_lat, longitude=o_lng),
            ],
            speedLevel="slow",
            behaviorType="patrol",
        ))

    return enemies
