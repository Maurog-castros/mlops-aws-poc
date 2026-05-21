from pathlib import Path

import joblib
from sklearn.linear_model import LinearRegression


MODEL_PATH = Path("models/model.joblib")


def main() -> None:
    MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)

    model = LinearRegression()
    model.fit([[1.0, 2.0, 3.0], [2.0, 3.0, 4.0]], [6.0, 9.0])

    joblib.dump(model, MODEL_PATH)
    print(f"Created smoke model at {MODEL_PATH}")


if __name__ == "__main__":
    main()

