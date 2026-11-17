import importlib
from unittest.mock import AsyncMock, Mock

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def server(monkeypatch):
    # Do not use credentials from the developer's .env in these tests.
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_KEY", "test-key")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "")
    monkeypatch.setenv("OPEN_ROUTER_API_KEY", "")
    monkeypatch.setenv(
        "CORS_ORIGINS", " http://localhost:5173, http://127.0.0.1:3000, "
    )
    import main

    return importlib.reload(main)


def test_health_and_docs(server):
    with TestClient(server.app) as client:
        assert client.get("/").json() == {"status": "ok"}
        assert client.get("/docs").status_code == 200
        assert client.get("/openapi.json").status_code == 200


def test_missing_auth_is_rejected(server):
    with TestClient(server.app) as client:
        assert client.get("/get-all-recipes").status_code == 401


@pytest.mark.parametrize("method", ["GET", "POST", "DELETE"])
@pytest.mark.parametrize("origin", ["http://localhost:5173", "http://127.0.0.1:3000"])
def test_browser_preflight(server, method, origin):
    with TestClient(server.app) as client:
        response = client.options(
            "/get-all-recipes",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": method,
                "Access-Control-Request-Headers": "auth-header,content-type",
            },
        )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin
    assert "access-control-allow-credentials" not in response.headers


@pytest.mark.parametrize(
    "origin,method",
    [
        ("https://untrusted.example", "GET"),
        ("http://localhost:5173.evil.example", "GET"),
        ("http://localhost:5173", "PUT"),
    ],
)
def test_browser_preflight_rejects_other_origins_or_methods(server, origin, method):
    with TestClient(server.app) as client:
        response = client.options(
            "/get-all-recipes",
            headers={"Origin": origin, "Access-Control-Request-Method": method},
        )
    assert response.status_code == 400


def test_browser_can_read_auth_error(server):
    with TestClient(server.app) as client:
        response = client.get(
            "/get-all-recipes", headers={"Origin": "http://localhost:5173"}
        )
    assert response.status_code == 401
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"


def test_empty_origins_preserve_production_behavior(server, monkeypatch):
    monkeypatch.setenv("CORS_ORIGINS", "")
    server = importlib.reload(server)
    with TestClient(server.app) as client:
        response = client.get("/", headers={"Origin": "http://localhost:5173"})
    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers


def test_wildcard_origins_are_rejected(server, monkeypatch):
    monkeypatch.setenv("CORS_ORIGINS", "*")
    with pytest.raises(ValueError, match="exact origins"):
        importlib.reload(server)


def test_missing_openrouter_key_does_not_scrape(server, monkeypatch):
    dao = Mock()
    dao.get_recipe.return_value = None
    dao.get_user_limit.return_value = 10
    dao.count_recipes.return_value = 0
    monkeypatch.setattr(server, "get_db_client", Mock())
    monkeypatch.setattr(server, "RecipeDao", Mock(return_value=dao))
    monkeypatch.setattr(server, "validate_public_url", Mock())
    scrape = AsyncMock()
    browser = AsyncMock()
    extract = Mock()
    monkeypatch.setattr(server.url_extractor, "extract_url_contents", scrape)
    monkeypatch.setattr(server, "get_browser", browser)
    monkeypatch.setattr(server, "extract_recipe", extract)
    with TestClient(server.app) as client:
        response = client.get("/get-recipe/https://example.com/recipe")
    assert response.status_code == 503
    assert "OPEN_ROUTER_API_KEY" in response.json()["detail"]
    browser.assert_not_called()
    scrape.assert_not_called()
    extract.assert_not_called()
    dao.insert.assert_not_called()
