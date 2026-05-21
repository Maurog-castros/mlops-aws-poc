import json
import logging
import sys
import time
from collections.abc import Awaitable, Callable
from typing import Any

from fastapi import Request, Response


LOGGER_NAME = "mlops_aws_poc"
PROCESS_TIME_HEADER = "X-Process-Time-Ms"


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        for key, value in record.__dict__.items():
            if key.startswith("_"):
                payload[key[1:]] = value

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, default=str)


def configure_logging() -> logging.Logger:
    logger = logging.getLogger(LOGGER_NAME)
    logger.setLevel(logging.INFO)
    logger.propagate = False

    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)

    return logger


logger = configure_logging()


async def log_requests(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    started_at = time.perf_counter()

    try:
        response = await call_next(request)
    except Exception:
        duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
        logger.exception(
            "request_failed",
            extra={
                "_method": request.method,
                "_path": request.url.path,
                "_duration_ms": duration_ms,
            },
        )
        raise

    duration_ms = round((time.perf_counter() - started_at) * 1000, 2)
    response.headers[PROCESS_TIME_HEADER] = str(duration_ms)

    logger.info(
        "request_completed",
        extra={
            "_method": request.method,
            "_path": request.url.path,
            "_status_code": response.status_code,
            "_duration_ms": duration_ms,
        },
    )

    return response

