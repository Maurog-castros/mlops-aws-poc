import os
from pathlib import Path

from fastapi import FastAPI, HTTPException, status

from app.schemas import PredictionRequest, PredictionResponse
from src.predict import DEFAULT_MODEL_PATH, ModelUnavailableError, predict

app = FastAPI(title="MLOps AWS PoC")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/predict", response_model=PredictionResponse)
def predict_endpoint(payload: PredictionRequest) -> PredictionResponse:
    model_path = Path(os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH)))

    try:
        prediction = predict(payload.features, model_path)
    except ModelUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model artifact is not available.",
        ) from exc

    return PredictionResponse(
        prediction=prediction,
        model_path=str(model_path),
    )
