import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_THRESHOLDS = {
    "feature_means": 0.25,
    "feature_stds": 0.50,
}


def relative_delta(current: float, baseline: float) -> float:
    if baseline == 0:
        return abs(current)

    return abs(current - baseline) / abs(baseline)


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, default=Path("data/drift_baseline.json"))
    parser.add_argument("--current", type=Path, required=True)
    args = parser.parse_args()

    baseline = load_json(args.baseline)
    current = load_json(args.current)
    alerts: list[str] = []

    baseline_features = set(baseline["features"])
    current_features = set(current["features"])
    if current_features != baseline_features:
        alerts.append("feature_contract_changed")

    for group, threshold in DEFAULT_THRESHOLDS.items():
        for feature_name in sorted(baseline_features & current_features):
            delta = relative_delta(
                float(current[group][feature_name]),
                float(baseline[group][feature_name]),
            )
            if delta >= threshold:
                alerts.append(f"{feature_name}_{group}_drift")

    result = {
        "status": "drift_detected" if alerts else "ok",
        "alerts": alerts,
    }

    print(json.dumps(result, indent=2))

    if alerts:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
