from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split


BASE_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BASE_DIR / "models"
REGISTRY_DIR = MODELS_DIR / "registry"
DATA_DIR = BASE_DIR / "data"

MODEL_PATH = MODELS_DIR / "model.joblib"
METADATA_PATH = REGISTRY_DIR / "baseline_regressor_v1.json"
DRIFT_BASELINE_PATH = DATA_DIR / "drift_baseline.json"
FEATURE_NAMES = ["tenure", "monthly_charges", "support_tickets"]
RANDOM_SEED = 42


def build_synthetic_dataset() -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(RANDOM_SEED)

    tenure = rng.integers(0, 73, size=1000)
    monthly_charges = rng.uniform(20.0, 120.0, size=1000)
    support_tickets = rng.poisson(2.0, size=1000)

    noise = rng.normal(0.0, 2.0, size=1000)
    risk_score = (
        (4.0 * support_tickets)
        + (0.25 * monthly_charges)
        - (0.08 * tenure)
        + noise
    )

    features = np.column_stack([tenure, monthly_charges, support_tickets])
    return features, risk_score


def main() -> None:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    REGISTRY_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    features, target = build_synthetic_dataset()
    x_train, x_test, y_train, y_test = train_test_split(
        features,
        target,
        test_size=0.2,
        random_state=RANDOM_SEED,
    )

    model = RandomForestRegressor(
        n_estimators=100,
        max_depth=8,
        random_state=RANDOM_SEED,
        n_jobs=-1,
    )
    model.fit(x_train, y_train)

    predictions = model.predict(x_test)
    mae = mean_absolute_error(y_test, predictions)
    r2 = r2_score(y_test, predictions)

    joblib.dump(model, MODEL_PATH)

    trained_at = datetime.now(timezone.utc).isoformat()
    metadata = {
        "model_name": "baseline_regressor",
        "model_version": "v1",
        "trained_at": trained_at,
        "metric_name": "mae",
        "metric_value": float(mae),
        "secondary_metrics": {
            "r2": float(r2),
        },
        "dataset_name": "synthetic_logistics_regression",
        "artifact_path": "models/model.joblib",
        "status": "candidate",
        "features": FEATURE_NAMES,
    }

    with METADATA_PATH.open("w", encoding="utf-8") as file:
        json.dump(metadata, file, indent=2, ensure_ascii=False)

    drift_baseline = {
        "dataset_name": "synthetic_logistics_regression",
        "features": FEATURE_NAMES,
        "feature_means": {
            name: float(value)
            for name, value in zip(FEATURE_NAMES, x_train.mean(axis=0), strict=True)
        },
        "feature_stds": {
            name: float(value)
            for name, value in zip(FEATURE_NAMES, x_train.std(axis=0), strict=True)
        },
        "created_at": trained_at,
    }

    with DRIFT_BASELINE_PATH.open("w", encoding="utf-8") as file:
        json.dump(drift_baseline, file, indent=2, ensure_ascii=False)

    print(f"Model saved: {MODEL_PATH}")
    print(f"Metadata saved: {METADATA_PATH}")
    print(f"Drift baseline saved: {DRIFT_BASELINE_PATH}")
    print(f"MAE: {mae:.4f}")
    print(f"R2: {r2:.4f}")


if __name__ == "__main__":
    main()
