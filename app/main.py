import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, status

from app.observability import log_requests, logger
from app.schemas import ModelInfoResponse, PredictionRequest, PredictionResponse
from src.model_artifacts import download_s3_artifact
from src.model_registry import (
    DEFAULT_MODEL_METADATA_PATH,
    load_model_metadata,
    summarize_features,
)
from src.predict import DEFAULT_MODEL_PATH, ModelUnavailableError, predict


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    model_path = Path(os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH)))
    model_s3_uri = os.getenv("MODEL_S3_URI")

    if model_s3_uri:
        try:
            download_s3_artifact(model_s3_uri, model_path)
            logger.info(
                "model_downloaded",
                extra={
                    "_model_s3_uri": model_s3_uri,
                    "_model_path": str(model_path),
                },
            )
        except Exception:
            logger.exception(
                "model_download_failed",
                extra={
                    "_model_s3_uri": model_s3_uri,
                    "_model_path": str(model_path),
                },
            )
            raise

    logger.info(
        "application_started",
        extra={
            "_model_path": str(model_path),
            "_model_s3_uri": model_s3_uri,
        },
    )
    yield


app = FastAPI(title="MLOps AWS PoC", lifespan=lifespan)
app.middleware("http")(log_requests)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/model", response_model=ModelInfoResponse)
def model_info() -> ModelInfoResponse:
    metadata_path = Path(
        os.getenv("MODEL_METADATA_PATH", str(DEFAULT_MODEL_METADATA_PATH))
    )

    try:
        metadata = load_model_metadata(metadata_path)
    except FileNotFoundError as exc:
        logger.error(
            "model_metadata_unavailable",
            extra={
                "_metadata_path": str(metadata_path),
            },
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model metadata is not available.",
        ) from exc

    return ModelInfoResponse(
        model_name=metadata.model_name,
        model_version=metadata.model_version,
        status=metadata.status,
        metric_name=metadata.metric_name,
        metric_value=metadata.metric_value,
        dataset_name=metadata.dataset_name,
        artifact_path=metadata.artifact_path,
        metadata_path=str(metadata_path),
    )


@app.post("/predict", response_model=PredictionResponse)
def predict_endpoint(payload: PredictionRequest) -> PredictionResponse:
    model_path = Path(os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH)))
    feature_summary = summarize_features(payload.features)

    try:
        prediction = predict(payload.features, model_path)
    except ModelUnavailableError as exc:
        logger.error(
            "model_unavailable",
            extra={
                "_model_path": str(model_path),
                "_feature_count": len(payload.features),
                "_feature_min": feature_summary["feature_min"],
                "_feature_max": feature_summary["feature_max"],
                "_feature_mean": feature_summary["feature_mean"],
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
                "_feature_min": feature_summary["feature_min"],
                "_feature_max": feature_summary["feature_max"],
                "_feature_mean": feature_summary["feature_mean"],
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
            "_feature_min": feature_summary["feature_min"],
            "_feature_max": feature_summary["feature_max"],
            "_feature_mean": feature_summary["feature_mean"],
        },
    )

    return PredictionResponse(
        prediction=prediction,
        model_path=str(model_path),
    )
