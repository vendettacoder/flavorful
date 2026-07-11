from urllib.parse import urlparse

from bs4 import BeautifulSoup
from playwright.async_api import Browser, Route
from playwright.async_api import TimeoutError as PlaywrightTimeoutError

from url_safety import is_blocked_host

# Hard ceiling so a slow/hostile page can't tie up a browser tab indefinitely.
_NAV_TIMEOUT_MS = 60000


async def extract_url_contents(browser: Browser, url: str):
    page = await browser.new_page()

    async def _guard(route: Route):
        # Runs for every request the page makes — main document, redirects, and
        # sub-resources. Abort anything pointing at a non-public host so a 30x
        # redirect or embedded request can't reach internal addresses (SSRF).
        host = urlparse(route.request.url).hostname or ""
        if is_blocked_host(host):
            await route.abort()
        else:
            await route.continue_()

    await page.route("**/*", _guard)
    try:
        await page.goto(url, wait_until="domcontentloaded", timeout=_NAV_TIMEOUT_MS)
        # Best-effort: let late/JS content settle, but never fail on slow ad
        # traffic (ad-heavy blogs never reach networkidle).
        try:
            await page.wait_for_load_state("load", timeout=5000)
        except PlaywrightTimeoutError:
            pass
        html = await page.content()
    finally:
        await page.close()
    return BeautifulSoup(html, "html.parser")
