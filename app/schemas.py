from typing import Any

from pydantic import BaseModel, Field


class PredictionRequest(BaseModel):
    features: list[float] = Field(..., min_length=1)


class PredictionResponse(BaseModel):
    prediction: Any
    model_path: str

