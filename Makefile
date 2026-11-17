.PHONY: help setup dev check test

PORT ?= 8001

help:
	@printf '%s\n' 'make setup  Install Python packages and Chromium.' 'make dev    Run the server at http://127.0.0.1:$(PORT).' 'make check  Check hosted Supabase access without changing data.' 'make test   Run tests without hosted services.'

setup:
	uv sync --locked
	PLAYWRIGHT_SKIP_BROWSER_GC=1 uv run --locked playwright install chromium

# Bind to this Mac only. Set PORT=8002 if 8001 is in use.
dev:
	uv run --locked uvicorn main:app --reload --host 127.0.0.1 --port $(PORT)

check:
	uv run --locked python scripts/check_setup.py

test:
	uv run --locked python -m pytest -q
