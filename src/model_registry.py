import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_MODEL_METADATA_PATH = Path("models/registry/baseline_regressor_v1.json")


@dataclass(frozen=True)
class ModelMetadata:
    model_name: str
    model_version: str
    trained_at: str
    metric_name: str
    metric_value: float
    dataset_name: str
    artifact_path: str
    status: str

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "ModelMetadata":
        return cls(
            model_name=str(payload["model_name"]),
            model_version=str(payload["model_version"]),
            trained_at=str(payload["trained_at"]),
            metric_name=str(payload["metric_name"]),
            metric_value=float(payload["metric_value"]),
            dataset_name=str(payload["dataset_name"]),
            artifact_path=str(payload["artifact_path"]),
            status=str(payload["status"]),
        )


def load_model_metadata(path: Path = DEFAULT_MODEL_METADATA_PATH) -> ModelMetadata:
    with path.open("r", encoding="utf-8") as file:
        return ModelMetadata.from_dict(json.load(file))


def summarize_features(features: list[float]) -> dict[str, float | int]:
    count = len(features)
    total = sum(features)

    return {
        "feature_count": count,
        "feature_min": min(features),
        "feature_max": max(features),
        "feature_mean": total / count,
    }

