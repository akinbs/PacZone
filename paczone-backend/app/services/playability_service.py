from app.schemas.location import LocationRequest


def compute_score(request: LocationRequest, scenario: str) -> int:
    if scenario in ("gpsWeak", "speedTooHigh", "noData"):
        return 0
    if scenario == "failed":
        # Low score with noise from accuracy
        return max(10, min(35, 18 + int(request.accuracy * 0.5)))
    if scenario == "partial":
        # Mid-range score
        accuracy_bonus = max(0, 10 - int(request.accuracy / 2))
        return min(74, 55 + accuracy_bonus)
    # success
    accuracy_bonus = max(0, 10 - int(request.accuracy / 2))
    return min(99, 78 + accuracy_bonus)
