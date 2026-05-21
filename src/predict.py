from pathlib import Path
from typing import Any, Sequence

import joblib


DEFAULT_MODEL_PATH = Path("models/model.joblib")


class ModelUnavailableError(RuntimeError):
    pass


def predict(features: Sequence[float], model_path: Path = DEFAULT_MODEL_PATH) -> Any:
    if not model_path.exists():
        raise ModelUnavailableError(f"Model artifact not found: {model_path}")

    model = joblib.load(model_path)
    raw_prediction = model.predict([list(features)])

    if hasattr(raw_prediction, "tolist"):
        prediction = raw_prediction.tolist()
    else:
        prediction = list(raw_prediction)

    return prediction[0]
