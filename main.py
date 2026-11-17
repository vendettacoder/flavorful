import asyncio
import base64
import json
import os
from contextlib import asynccontextmanager

import html2text
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from playwright.async_api import Browser, async_playwright
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from supabase import create_client

import url_extractor
from recipe_dao import RecipeDao, RecipeDto, get_db_client
from recipe_extractor import extract_recipe
from recipe_timing import time_recipe_save, timed_step
from url_safety import validate_public_url
from web_host import WebAppFiles

load_dotenv()


def _user_key(request: Request) -> str:
    """Rate-limit key: the Supabase user id from the JWT, else the client IP.

    The payload is base64-decoded WITHOUT signature verification — this is only
    used to bucket rate limits. Real token validation happens in get_db_client().
    """
    auth = request.headers.get("auth-header", "")
    if auth.startswith("Bearer "):
        parts = auth.split(" ", 1)[1].split(".")
        if len(parts) == 3:
            try:
                padded = parts[1] + "=" * (-len(parts[1]) % 4)
                sub = json.loads(base64.urlsafe_b64decode(padded)).get("sub")
                if sub:
                    return str(sub)
            except Exception:
                pass
    return get_remote_address(request)


def _user_id_from_token(auth_header: str) -> str | None:
    """The Supabase user id (JWT `sub`) from the auth header, or None.

    The payload is base64-decoded WITHOUT signature verification — get_db_client
    has already validated the token against Supabase before this is used. We only
    need the id to target the auth-user deletion.
    """
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    parts = auth_header.split(" ", 1)[1].split(".")
    if len(parts) != 3:
        return None
    try:
        padded = parts[1] + "=" * (-len(parts[1]) % 4)
        sub = json.loads(base64.urlsafe_b64decode(padded)).get("sub")
        return str(sub) if sub else None
    except Exception:
        return None


def _delete_supabase_auth_user(user_id: str) -> bool:
    """Permanently delete the Supabase auth user via the admin API.

    Requires the service-role key (SUPABASE_SERVICE_ROLE_KEY) — the user-scoped
    token cannot delete its own auth record. Returns True on success; False if
    the key is absent or the call fails (the user's data has still been wiped).
    """
    service_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    if not service_key or not user_id:
        print(
            "[delete-account] SUPABASE_SERVICE_ROLE_KEY missing or no user id; "
            "data wiped but auth user not deleted",
            flush=True,
        )
        return False
    try:
        admin = create_client(os.getenv("SUPABASE_URL", ""), service_key)
        admin.auth.admin.delete_user(user_id)
        return True
    except Exception as e:
        print(f"[delete-account] auth user deletion failed: {e}", flush=True)
        return False


limiter = Limiter(key_func=_user_key)


browser: Browser | None = None
_playwright = None
_browser_lock = asyncio.Lock()


async def get_browser() -> Browser:
    """Lazily start Playwright AND launch Chromium on first use; reuse after.

    Doing either at startup blocked uvicorn from accepting connections (the
    Playwright driver spawn + Chromium boot take seconds), so Fly's proxy gave
    up on the first request after a scale-to-zero wake (PM05/PC01). Deferring
    everything to first use lets the server bind immediately; only the first
    scrape pays the boot cost.
    """
    global browser, _playwright
    if browser is None or not browser.is_connected():
        async with _browser_lock:
            if _playwright is None:
                _playwright = await async_playwright().start()
            if browser is None or not browser.is_connected():
                # --no-sandbox: Chromium's sandbox can't initialize inside a
                # container (no user namespaces); safe here as headless Chromium
                # runs isolated in the container and only fetches pages.
                browser = await _playwright.chromium.launch(
                    headless=True, args=["--no-sandbox"]
                )
    return browser


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Do NOTHING blocking at startup so uvicorn binds the port immediately and
    # Fly's proxy can connect on a cold-start wake. Playwright + Chromium start
    # lazily on the first scrape (see get_browser()).
    yield
    if browser is not None and browser.is_connected():
        await browser.close()
    if _playwright is not None:
        await _playwright.stop()


app = FastAPI(lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Allow only the browser origins explicitly set for this server.
# Leaving CORS_ORIGINS unset preserves the existing production behavior.
cors_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "").split(",")
    if origin.strip()
]
if "*" in cors_origins:
    raise ValueError("CORS_ORIGINS must list exact origins, not *")
if cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_methods=["GET", "POST", "DELETE"],
        allow_headers=["auth-header", "Content-Type"],
    )


@app.get("/health")
async def health():
    """Check that the server responds. Does not check Supabase or Chromium."""
    return {"status": "ok"}


@app.get("/get-all-recipes")
async def get_recipes(auth_header: str = Header(None)):
    supabase_client = get_db_client(auth_header)
    recipe_dao = RecipeDao(supabase_client=supabase_client)
    recipes = recipe_dao.get_recipes()
    return recipes


@app.get("/get-recipe/{url:path}")
@limiter.limit("10/minute;100/day")
async def recipe(request: Request, url: str, auth_header: str = Header(None)):
    with time_recipe_save() as save_timing:
        with timed_step("db_client"):
            supabase_client = get_db_client(auth_header)
        with timed_step("url_validation"):
            validate_public_url(url)  # Keep the existing SSRF guard.
        recipe_dao = RecipeDao(supabase_client=supabase_client)
        with timed_step("db_duplicate_lookup"):
            result = recipe_dao.get_recipe(public_url=url)
        if result:
            save_timing["result"] = "already_saved"
            return f"User ID={result['user_id']} already has a recipe stored .. inserted Recipe ID={result['recipe_id']}"

        # Enforce the per-user recipe limit BEFORE the costly scrape + LLM call.
        with timed_step("db_limit_lookup"):
            limit = recipe_dao.get_user_limit()
        with timed_step("db_recipe_count"):
            recipe_count = recipe_dao.count_recipes()
        if recipe_count >= limit:
            raise HTTPException(
                status_code=409,
                detail=f"You've reached your limit of {limit} recipes. "
                "Delete one to make room.",
            )

        if not os.getenv("OPEN_ROUTER_API_KEY", "").strip():
            raise HTTPException(
                status_code=503,
                detail="Recipe extraction is not configured. "
                "Set OPEN_ROUTER_API_KEY on the server.",
            )

        try:
            with timed_step("browser_ready"):
                recipe_browser = await get_browser()
            with timed_step("page_read"):
                page_content = await url_extractor.extract_url_contents(
                    browser=recipe_browser, url=url
                )
        except HTTPException:
            raise
        except Exception:
            # The failed timing record contains the error type, not the URL.
            raise HTTPException(
                status_code=400,
                detail="Couldn't open that link. Check the URL and try again.",
            )

        with timed_step("page_to_text") as text_timing:
            converter = html2text.HTML2Text()
            converter.ignore_links = True
            page_markdown = converter.handle(str(page_content))
            text_timing["page_chars"] = len(page_markdown)
        with timed_step("model_total") as model_timing:
            recipe_json = extract_recipe(page_content=page_markdown)
            if not recipe_json:
                model_timing["status"] = "invalid_response"
        if not recipe_json:
            raise HTTPException(
                status_code=503,
                detail="Couldn't extract this recipe right now — the recipe AI "
                "service is busy or rate-limited. Please try again in a minute.",
            )

        # No real recipe on the page: the LLM returns {"no_recipe": true}, or the
        # result has neither a name nor ingredients. Don't store an empty shell.
        no_recipe = recipe_json.get("no_recipe") is True
        has_content = bool(recipe_json.get("recipe_name")) or bool(
            recipe_json.get("ingredients")
        )
        if no_recipe or not has_content:
            raise HTTPException(
                status_code=422,
                detail="No recipe found on that page.",
            )

        recipe_dto = RecipeDto(
            public_url=url,
            recipe_json=recipe_json,
        )
        with timed_step("db_insert"):
            recipe_id = recipe_dao.insert(recipe_dto)
        save_timing["result"] = "saved"
        return f"Successfully inserted Recipe ID={recipe_id}"


@app.get("/search-recipes")
@limiter.limit("30/minute")
async def search_recipes(
    request: Request, q: str = "", auth_header: str = Header(None)
):
    supabase_client = get_db_client(auth_header)
    recipe_dao = RecipeDao(supabase_client=supabase_client)
    return recipe_dao.search_recipes(query=q)


@app.post("/favorite-recipe/{recipe_id}")
async def favorite_recipe(recipe_id: str, auth_header: str = Header(None)):
    supabase_client = get_db_client(auth_header)
    recipe_dao = RecipeDao(supabase_client=supabase_client)
    return {"is_favorited": recipe_dao.toggle_favorite(recipe_id=recipe_id)}


@app.delete("/delete-recipe/{recipe_id}")
async def delete_recipe(recipe_id: str, auth_header: str = Header(None)):
    supabase_client = get_db_client(auth_header)
    recipe_dao = RecipeDao(supabase_client=supabase_client)
    deleted = recipe_dao.delete_by_id(recipe_id=recipe_id)
    return {"deleted": deleted}


@app.delete("/delete-account")
async def delete_account(auth_header: str = Header(None)):
    """Permanently delete the caller's account and all their data.

    Required by App Store Review Guideline 5.1.1(v). Wipes the user's recipes
    (RLS-scoped) first, then deletes the Supabase auth user via the admin API.
    """
    supabase_client = get_db_client(auth_header)  # validates the token
    recipe_dao = RecipeDao(supabase_client=supabase_client)
    deleted_recipes = recipe_dao.delete_all()
    user_id = _user_id_from_token(auth_header)
    account_deleted = _delete_supabase_auth_user(user_id)
    return {"deleted_recipes": deleted_recipes, "account_deleted": account_deleted}


# Keep API routes ahead of the static app. Local API-only runs retain GET /.
web_build_dir = os.getenv("WEB_BUILD_DIR", "").strip()
if web_build_dir:
    app.mount("/", WebAppFiles(web_build_dir), name="web")
else:
    app.add_api_route("/", health, methods=["GET"], include_in_schema=False)
