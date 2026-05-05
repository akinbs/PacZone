from typing import List
from app.schemas.coin import CoinSchema
from app.schemas.location import LocationRequest
from app.schemas.zone import GeoPoint
from app.utils.geo_math import offset_point
from app.utils.id_generator import new_id

_NORMAL_OFFSETS: list[tuple[float, float]] = [
    (20, 0), (-20, 0), (0, 20), (0, -20),
    (15, 15), (-15, 15), (15, -15), (-15, -15),
    (35, 0), (-35, 0), (0, 35), (0, -35),
]

_POWER_OFFSETS: list[tuple[float, float]] = [(50, 0), (-50, 0)]


def generate_coins(request: LocationRequest) -> List[CoinSchema]:
    lat, lng = request.latitude, request.longitude
    coins: List[CoinSchema] = []

    for dn, de in _NORMAL_OFFSETS:
        nlat, nlng = offset_point(lat, lng, dn, de)
        coins.append(CoinSchema(
            id=new_id("coin"),
            position=GeoPoint(latitude=nlat, longitude=nlng),
            type="normal",
            value=10,
        ))

    for dn, de in _POWER_OFFSETS:
        nlat, nlng = offset_point(lat, lng, dn, de)
        coins.append(CoinSchema(
            id=new_id("coin"),
            position=GeoPoint(latitude=nlat, longitude=nlng),
            type="power",
            value=50,
        ))

    return coins
