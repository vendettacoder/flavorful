import importlib

import pytest
from fastapi.testclient import TestClient

from web_host import WebAppFiles


@pytest.fixture
def web_client(tmp_path, monkeypatch):
    web = tmp_path / "web"
    web.mkdir()
    (web / "index.html").write_text("<!doctype html><title>Flavorful</title>")
    (web / "flutter_bootstrap.js").write_text("console.log('bootstrap');")
    (web / "main.dart.js").write_text("console.log('app');")
    (web / "engine.wasm").write_bytes(b"\x00asm")
    (web / ".env").write_text("not-public")
    secret = tmp_path / "secret.txt"
    secret.write_text("not-public")
    (web / "outside.txt").symlink_to(secret)
    monkeypatch.setenv("WEB_BUILD_DIR", str(web))
    import main

    importlib.reload(main)
    with TestClient(main.app) as client:
        yield client
    monkeypatch.delenv("WEB_BUILD_DIR")
    importlib.reload(main)


@pytest.mark.parametrize(
    "path", ["/", "/sign-in", "/auth/callback?code=test", "/recipes/example"]
)
def test_web_routes(web_client, path):
    response = web_client.get(path)
    assert response.status_code == 200
    assert "Flavorful" in response.text
    assert response.headers["content-type"].startswith("text/html")
    assert response.headers["cache-control"] == "no-cache"
    assert response.headers["referrer-policy"] == "no-referrer"


def test_assets_and_head(web_client):
    response = web_client.get("/flutter_bootstrap.js")
    assert response.status_code == 200
    assert "javascript" in response.headers["content-type"]
    assert web_client.get("/engine.wasm").headers["content-type"] == "application/wasm"
    assert web_client.head("/auth/callback").content == b""


@pytest.mark.parametrize(
    "path",
    [
        "/.env",
        "/%2eenv",
        "/outside.txt",
        "/%2e%2e/secret.txt",
        "/main.py",
        "/missing.js",
        "/missing-api",
    ],
)
def test_private_and_missing_files_stay_404(web_client, path):
    assert web_client.get(path).status_code == 404


def test_api_and_health_stay_separate(web_client):
    assert web_client.get("/health").json() == {"status": "ok"}
    assert web_client.get("/get-all-recipes").status_code == 401
    assert web_client.get("/get-recipe/https://example.com/recipe").status_code == 401
    assert web_client.post("/favorite-recipe/example").status_code == 401
    assert web_client.delete("/delete-recipe/example").status_code == 401


def test_missing_build_fails_before_start(tmp_path):
    with pytest.raises(RuntimeError, match="missing required files"):
        WebAppFiles(str(tmp_path))
