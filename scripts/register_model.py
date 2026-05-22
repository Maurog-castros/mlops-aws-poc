import argparse
import json
from pathlib import Path


REQUIRED_FIELDS = {
    "model_name",
    "model_version",
    "trained_at",
    "metric_name",
    "metric_value",
    "secondary_metrics",
    "dataset_name",
    "artifact_path",
    "status",
    "features",
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata_path", type=Path)
    parser.add_argument("--registry-dir", type=Path, default=Path("models/registry"))
    args = parser.parse_args()

    with args.metadata_path.open("r", encoding="utf-8") as file:
        payload = json.load(file)

    missing = REQUIRED_FIELDS - payload.keys()
    if missing:
        raise SystemExit(f"Missing metadata fields: {sorted(missing)}")

    target = args.registry_dir / (
        f"{payload['model_name']}_{payload['model_version']}.json"
    )

    if target.exists() and target.resolve() != args.metadata_path.resolve():
        raise SystemExit(f"Model version already exists: {target}")

    print(f"Model metadata is valid: {target}")


if __name__ == "__main__":
    main()
