from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

BASE_PAYLOAD = {
    "latitude": 41.012345,
    "longitude": 29.012345,
    "accuracy": 8.5,
    "heading": 120.0,
    "speed": 1.2,
    "scanSizeMeters": 150,
}


def _analyze(extra: dict = {}) -> dict:
    return client.post("/api/v1/dynamic-zones/analyze", json={**BASE_PAYLOAD, **extra}).json()


def test_success():
    data = _analyze()
    assert data["playable"] is True
    assert data["status"] == "success"
    assert data["zone"] is not None
    assert len(data["zone"]["coins"]) > 0


def test_partial():
    data = _analyze({"debugScenario": "partial"})
    assert data["playable"] is True
    assert data["status"] == "partial"
    assert data["zone"]["modeType"] == "short_run"


def test_failed():
    data = _analyze({"debugScenario": "failed"})
    assert data["playable"] is False
    assert data["status"] == "failed"
    assert data["zone"] is None


def test_gps_weak_by_accuracy():
    data = _analyze({"accuracy": 35.0})
    assert data["playable"] is False
    assert data["status"] == "gpsWeak"


def test_speed_too_high():
    # 6 m/s = 21.6 km/h > 15 km/h threshold
    data = _analyze({"speed": 6.0})
    assert data["playable"] is False
    assert data["status"] == "speedTooHigh"


def test_invalid_latitude():
    response = client.post(
        "/api/v1/dynamic-zones/analyze",
        json={**BASE_PAYLOAD, "latitude": 150.0},
    )
    assert response.status_code == 422


def test_invalid_debug_scenario():
    response = client.post(
        "/api/v1/dynamic-zones/analyze",
        json={**BASE_PAYLOAD, "debugScenario": "invalid_value"},
    )
    assert response.status_code == 422
