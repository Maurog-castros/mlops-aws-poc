import argparse
from pathlib import Path

import joblib
from sklearn.linear_model import LinearRegression


MODEL_PATH = Path("models/model.joblib")


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a small smoke-test model.")
    parser.add_argument("--output", type=Path, default=MODEL_PATH)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)

    model = LinearRegression()
    model.fit(
        [
            [0.0, 20.0, 0.0],
            [12.0, 89.5, 3.0],
            [36.0, 70.0, 1.0],
            [72.0, 110.0, 5.0],
        ],
        [1.0, 18.5, 4.0, 24.0],
    )

    joblib.dump(model, args.output)
    print(f"Created smoke model at {args.output}")


if __name__ == "__main__":
    main()
