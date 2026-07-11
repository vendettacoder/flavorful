# Flavorful backend — FastAPI + Playwright (Chromium).
# Built for Fly.io but works on any container host.

FROM python:3.14-slim

# uv — fast Python package manager (matches the local uv.lock workflow).
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    # Install browsers to a fixed system path (not $HOME) so they're found at runtime.
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

# 1) Install Python deps first, without the app, for better layer caching.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# 2) Chromium + its OS-level dependencies (fonts, libs). --with-deps runs apt.
RUN .venv/bin/playwright install --with-deps chromium

# 3) Copy the app and finish the install.
COPY . .
RUN uv sync --frozen --no-dev

EXPOSE 8000

# fastapi[standard] provides the `fastapi run` production server.
CMD [".venv/bin/fastapi", "run", "main.py", "--host", "0.0.0.0", "--port", "8000"]
