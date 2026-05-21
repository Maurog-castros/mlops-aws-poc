from fastapi.testclient import TestClient
import joblib

from app.observability import PROCESS_TIME_HEADER
from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert PROCESS_TIME_HEADER in response.headers
    assert response.json() == {"status": "ok"}


class DummyModel:
    def predict(self, rows):
        return [sum(rows[0])]


def test_predict_valid_payload(monkeypatch, tmp_path):
    model_path = tmp_path / "model.joblib"
    joblib.dump(DummyModel(), model_path)
    monkeypatch.setattr("app.main.DEFAULT_MODEL_PATH", model_path)

    response = client.post("/predict", json={"features": [1.0, 2.5, 3.5]})

    assert response.status_code == 200
    assert PROCESS_TIME_HEADER in response.headers
    assert response.json() == {
        "prediction": 7.0,
        "model_path": str(model_path),
    }


def test_predict_invalid_payload():
    response = client.post("/predict", json={"features": []})

    assert response.status_code == 422
    assert PROCESS_TIME_HEADER in response.headers


def test_predict_model_unavailable(monkeypatch, tmp_path):
    model_path = tmp_path / "missing.joblib"
    monkeypatch.setattr("app.main.DEFAULT_MODEL_PATH", model_path)

    response = client.post("/predict", json={"features": [1.0]})

    assert response.status_code == 503
    assert PROCESS_TIME_HEADER in response.headers
    assert response.json() == {"detail": "Model artifact is not available."}
