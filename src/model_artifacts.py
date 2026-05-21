from pathlib import Path
from urllib.parse import urlparse

import boto3


def parse_s3_uri(uri: str) -> tuple[str, str]:
    parsed = urlparse(uri)

    if parsed.scheme != "s3" or not parsed.netloc or not parsed.path:
        raise ValueError(f"Invalid S3 URI: {uri}")

    return parsed.netloc, parsed.path.lstrip("/")


def download_s3_artifact(uri: str, destination: Path) -> None:
    bucket, key = parse_s3_uri(uri)
    destination.parent.mkdir(parents=True, exist_ok=True)

    boto3.client("s3").download_file(bucket, key, str(destination))
