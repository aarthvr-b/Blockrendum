from fastapi.testclient import TestClient
from src.blockrendum.main import app
from src.blockrendum.config import get_settings

client = TestClient(app)
settings = get_settings()

def test_health():
    response = client.get(f"{settings.api_prefix}/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
