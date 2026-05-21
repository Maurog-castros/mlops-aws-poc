import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, status

from app.observability import log_requests, logger
from app.schemas import PredictionRequest, PredictionResponse
from src.predict import DEFAULT_MODEL_PATH, ModelUnavailableError, predict


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    logger.info(
        "application_started",
        extra={
            "_model_path": os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH)),
        },
    )
    yield


app = FastAPI(title="MLOps AWS PoC", lifespan=lifespan)
app.middleware("http")(log_requests)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/predict", response_model=PredictionResponse)
def predict_endpoint(payload: PredictionRequest) -> PredictionResponse:
    model_path = Path(os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH)))

    try:
        prediction = predict(payload.features, model_path)
    except ModelUnavailableError as exc:
        logger.error(
            "model_unavailable",
            extra={
                "_model_path": str(model_path),
                "_feature_count": len(payload.features),
            },
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model artifact is not available.",
        ) from exc
    except Exception as exc:
        logger.exception(
            "prediction_failed",
            extra={
                "_model_path": str(model_path),
                "_feature_count": len(payload.features),
            },
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Prediction failed.",
        ) from exc

    logger.info(
        "prediction_completed",
        extra={
            "_model_path": str(model_path),
            "_feature_count": len(payload.features),
        },
    )

    return PredictionResponse(
        prediction=prediction,
        model_path=str(model_path),
    )
