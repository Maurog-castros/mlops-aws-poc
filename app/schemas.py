from typing import Any

from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    features: list[float] = Field(..., min_length=1)


class PredictionResponse(BaseModel):
    prediction: Any
    model_path: str


class ModelInfoResponse(BaseModel):
    model_name: str
    model_version: str
    status: str
    metric_name: str
    metric_value: float
    dataset_name: str
    artifact_path: str
    metadata_path: str
