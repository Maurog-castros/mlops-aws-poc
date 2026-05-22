from typing import Any

from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    tenure: float = Field(..., ge=0)
    monthly_charges: float = Field(..., ge=0)
    support_tickets: int = Field(..., ge=0)

    def to_feature_vector(self) -> list[float]:
        return [
            self.tenure,
            self.monthly_charges,
            float(self.support_tickets),
        ]


class PredictionResponse(BaseModel):
    prediction: Any
    model_path: str


class ModelInfoResponse(BaseModel):
    model_name: str
    model_version: str
    status: str
    metric_name: str
    metric_value: float
    secondary_metrics: dict[str, float] = Field(default_factory=dict)
    dataset_name: str
    artifact_path: str
    metadata_path: str
    features: list[str] = Field(default_factory=list)
