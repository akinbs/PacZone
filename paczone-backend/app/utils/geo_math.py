import math

_METERS_PER_DEGREE_LAT = 111_320.0


def meters_per_degree_lng(latitude: float) -> float:
    return _METERS_PER_DEGREE_LAT * math.cos(math.radians(latitude))


def offset_point(lat: float, lng: float, delta_north_m: float, delta_east_m: float) -> tuple[float, float]:
    """Return (lat, lng) shifted by delta_north_m north and delta_east_m east."""
    new_lat = lat + delta_north_m / _METERS_PER_DEGREE_LAT
    new_lng = lng + delta_east_m / meters_per_degree_lng(lat)
    return new_lat, new_lng
