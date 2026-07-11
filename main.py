import asyncio
import base64
import json
import os
from contextlib import asynccontextmanager

import html2text
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Request
from playwright.async_api import Browser, async_playwright
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from supabase import create_client

import url_extractor
from recipe_dao import RecipeDao, RecipeDto, get_db_client
from recipe_extractor import extract_recipe
from url_safety import validate_public_url

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

# No CORS middleware: the clients are native iOS/Android apps, which don't
# enforce CORS. If a browser-based web client is added later, re-add
# fastapi.middleware.cors.CORSMiddleware with the production origin(s).


@app.get("/")
async def health():
    """Liveness probe — returns 200 once startup (incl. Chromium launch) is done.
    Gives Fly a clean health signal and avoids a 404 on the base URL."""
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
    supabase_client = get_db_client(auth_header)
    validate_public_url(url)  # SSRF guard — raises 400 on internal/invalid URLs
    recipe_dao = RecipeDao(supabase_client=supabase_client)
    result = recipe_dao.get_recipe(public_url=url)
    if result:
        return f"User ID={result['user_id']} already has a recipe stored .. inserted Recipe ID={result['recipe_id']}"

    # Enforce the per-user recipe limit BEFORE the costly scrape + LLM call.
    limit = recipe_dao.get_user_limit()
    if recipe_dao.count_recipes() >= limit:
        raise HTTPException(
            status_code=409,
            detail=f"You've reached your limit of {limit} recipes. "
            "Delete one to make room.",
        )

    try:
        page_content = await url_extractor.extract_url_contents(
            browser=await get_browser(), url=url
        )
    except HTTPException:
        raise
    except Exception as e:
        # Log the real error server-side; return a generic message to the client.
        print(f"[fetch error] url={url} error={e}", flush=True)
        raise HTTPException(
            status_code=400,
            detail="Couldn't open that link. Check the URL and try again.",
        )

    converter = html2text.HTML2Text()
    converter.ignore_links = True

    page_markdown = converter.handle(str(page_content))
    recipe_json = extract_recipe(page_content=page_markdown)
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
    recipe_id = recipe_dao.insert(recipe_dto)

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
