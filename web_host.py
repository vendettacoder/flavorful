"""Serve the compiled web app without exposing server files or API fallbacks."""

from pathlib import Path
import re

from starlette.exceptions import HTTPException
from starlette.staticfiles import StaticFiles


class WebAppFiles(StaticFiles):
    def __init__(self, directory: str):
        root = Path(directory).resolve()
        for filename in ("index.html", "flutter_bootstrap.js", "main.dart.js"):
            if not (root / filename).is_file():
                raise RuntimeError(
                    "The configured web build is missing required files."
                )
        super().__init__(directory=root, html=False, follow_symlink=False)

    async def get_response(self, path, scope):
        if "\\" in path or any(
            part.startswith(".") for part in path.split("/") if part not in ("", ".")
        ):
            raise HTTPException(status_code=404)
        app_route = path in {
            "",
            ".",
            "sign-in",
            "auth/callback",
            "login-callback",
        } or bool(re.fullmatch(r"recipes/[^/]+", path))
        response = await super().get_response(
            "index.html" if app_route else path, scope
        )
        # Flutter's entry scripts are not content-hashed. Revalidate after deploys.
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        return response
