"""Per-import timings. Do not pass URLs, credentials, or recipe text as fields."""

import json
from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass
from datetime import datetime, timezone
from time import perf_counter
from uuid import uuid4


@dataclass
class _ImportTiming:
    request_id: str
    started: float
    model_attempts: int = 0


_current: ContextVar[_ImportTiming | None] = ContextVar("recipe_timing", default=None)


@contextmanager
def timed_step(stage: str, **fields):
    """Write one JSON record when a step ends, including errors and cancellation.

    The caller can add safe counts or a result code to the yielded dictionary.
    Calls outside an import do not emit timing records.
    """
    timing = _current.get()
    if timing is None:
        yield fields
        return

    if stage == "model_attempt":
        timing.model_attempts += 1
        fields["attempt"] = timing.model_attempts
    started = perf_counter()
    try:
        yield fields
    except BaseException as error:
        fields["status"] = "error"
        fields["error_type"] = type(error).__name__
        status_code = getattr(error, "status_code", None)
        if isinstance(status_code, int):
            fields["http_status"] = status_code
        raise
    finally:
        ended = perf_counter()
        fields.setdefault("status", "ok")
        print(
            json.dumps(
                {
                    **fields,
                    "event": "recipe_timing",
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "request_id": timing.request_id,
                    "stage": stage,
                    "duration_ms": round((ended - started) * 1000, 3),
                    "elapsed_ms": round((ended - timing.started) * 1000, 3),
                }
            ),
            flush=True,
        )


@contextmanager
def time_recipe_save():
    """Keep the same request ID across page reads, model retries, and the save."""
    timing = _ImportTiming(request_id=uuid4().hex, started=perf_counter())
    token = _current.set(timing)
    try:
        with timed_step("save_total") as fields:
            yield fields
    finally:
        _current.reset(token)
