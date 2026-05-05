from app.core.config import settings
from app.schemas.dynamic_zone import AnalyzeResponse
from app.schemas.location import LocationRequest
from app.services import (
    coin_generator_service,
    enemy_generator_service,
    playability_service,
    zone_generator_service,
)


def analyze(request: LocationRequest) -> AnalyzeResponse:
    # 1. GPS accuracy check
    if request.accuracy > settings.MAX_ALLOWED_ACCURACY_METERS:
        return AnalyzeResponse(
            playable=False,
            status="gpsWeak",
            playabilityScore=0,
            reason="Konum doğruluğu düşük.",
            suggestion="Açık alanda birkaç saniye bekleyip tekrar deneyin.",
        )

    # 2. Speed check (request.speed is m/s → convert to km/h)
    speed_kmh = request.speed * 3.6
    if speed_kmh > settings.MAX_ALLOWED_SPEED_KMH:
        return AnalyzeResponse(
            playable=False,
            status="speedTooHigh",
            playabilityScore=0,
            reason="Kullanıcı yürüyüş hızından daha hızlı hareket ediyor.",
            suggestion="PacZone yürüyüş alanlarında oynanabilir. Lütfen güvenli bir yaya alanında tekrar deneyin.",
        )

    # 3. Debug scenario override (dev-only)
    scenario = request.debugScenario or "success"

    return _build_response(request, scenario)


def _build_response(request: LocationRequest, scenario: str) -> AnalyzeResponse:
    score = playability_service.compute_score(request, scenario)

    if scenario == "noData":
        return AnalyzeResponse(
            playable=False,
            status="noData",
            playabilityScore=0,
            reason="Konum verisi alınamadı.",
            suggestion="İnternet bağlantınızı ve GPS ayarlarını kontrol edin.",
        )

    if scenario == "gpsWeak":
        return AnalyzeResponse(
            playable=False,
            status="gpsWeak",
            playabilityScore=0,
            reason="Konum doğruluğu düşük.",
            suggestion="Açık alanda birkaç saniye bekleyip tekrar deneyin.",
        )

    if scenario == "speedTooHigh":
        return AnalyzeResponse(
            playable=False,
            status="speedTooHigh",
            playabilityScore=0,
            reason="Kullanıcı yürüyüş hızından daha hızlı hareket ediyor.",
            suggestion="PacZone yürüyüş alanlarında oynanabilir. Lütfen güvenli bir yaya alanında tekrar deneyin.",
        )

    if scenario == "failed":
        return AnalyzeResponse(
            playable=False,
            status="failed",
            playabilityScore=score,
            reason="Yaya yolu yoğunluğu düşük veya araç yolları fazla.",
            suggestion="Park, kampüs, sahil yolu veya meydan gibi yaya alanlarında tekrar deneyin.",
        )

    # success or partial — generate zone
    zone = zone_generator_service.generate_zone(request, scenario)
    if zone is not None:
        coins = coin_generator_service.generate_coins(request)
        count = 1 if scenario == "partial" else 2
        enemies = enemy_generator_service.generate_enemies(request, count=count)
        zone.coins = [c.model_dump() for c in coins]
        zone.enemies = [e.model_dump() for e in enemies]

    if scenario == "partial":
        return AnalyzeResponse(
            playable=True,
            status="partial",
            playabilityScore=score,
            reason="Bu alanda sınırlı yaya yolu bulundu.",
            suggestion="Kısa bir PacZone oluşturuldu. Daha iyi deneyim için park veya kampüs gibi yaya alanlarında deneyebilirsin.",
            zone=zone,
        )

    return AnalyzeResponse(
        playable=True,
        status="success",
        playabilityScore=score,
        zone=zone,
    )
