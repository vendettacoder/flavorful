.PHONY: help setup dev check test

PORT ?= 8001

help:
	@printf '%s\n' 'make setup  Install Python packages and Chromium.' 'make dev    Run the server at http://127.0.0.1:$(PORT).' 'make check  Check hosted Supabase access without changing data.' 'make test   Run tests without hosted services.' 'make web    Run the live Flutter web app on port 5173.' 'make web-test  Check and test the shared app offline.' 'make web-build Build the live web app without deploying.' 'make web-demo  Build and run the offline sample app on port 5173.'

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

# Shared Flutter app. Override FLUTTER if the SDK is in a different directory.
FLUTTER ?= $(HOME)/development/flutter/bin/flutter
API_BASE_URL ?= http://127.0.0.1:8001
WEB_API_BASE_URL ?= https://flavorful.fly.dev

.PHONY: web web-test web-build web-demo web-demo-build

# Live auth and API. This does not run or change the backend.
web:
	cd flavorful-ios && $(FLUTTER) run -d web-server --web-hostname 127.0.0.1 --web-port 5173 --dart-define=API_BASE_URL=$(API_BASE_URL)

web-test:
	cd flavorful-ios && $(FLUTTER) analyze && $(FLUTTER) test

# Release build only. Does not deploy or contact the API.
web-build:
	cd flavorful-ios && $(FLUTTER) build web --no-web-resources-cdn --dart-define=FLAVORFUL_ENV=prod --dart-define=API_BASE_URL=$(WEB_API_BASE_URL)

# Explicit offline mode. Separate output prevents replacing the live build.
web-demo-build:
	cd flavorful-ios && $(FLUTTER) build web --no-web-resources-cdn --dart-define=FLAVORFUL_MOCK=true --output=build/web-demo

web-demo: web-demo-build
	python3 flavorful-ios/tool/serve_web.py --demo --port 5173
