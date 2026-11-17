import asyncio
import importlib
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import html2text
import pytest
import requests
from bs4 import BeautifulSoup
from fastapi import HTTPException
from fastapi.testclient import TestClient
from playwright.async_api import TimeoutError as PlaywrightTimeoutError

import recipe_extractor
import recipe_timing
from recipe_timing import time_recipe_save, timed_step


PRIVATE_TEXT = "private-recipe-text-do-not-log"
PRIVATE_URL = "https://example.com/private-recipe?secret=do-not-log"


def timing_records(output):
    return [
        json.loads(line)
        for line in output.splitlines()
        if line.startswith("{") and '"event": "recipe_timing"' in line
    ]


def model_response(*, status=200, recipe=None, body=None):
    if recipe is None:
        recipe = {"recipe_name": PRIVATE_TEXT, "ingredients": ["1 tomato"]}
    response = Mock(status_code=status)
    response.json.return_value = (
        body
        if body is not None
        else {
            "choices": [
                {"finish_reason": "stop", "message": {"content": json.dumps(recipe)}}
            ],
            "usage": {
                "prompt_tokens": 123,
                "completion_tokens": 45,
                "private": PRIVATE_TEXT,
            },
        }
    )
    if status >= 400:
        response.raise_for_status.side_effect = requests.HTTPError(PRIVATE_TEXT)
    return response


@pytest.fixture
def import_server(monkeypatch):
    # All hosted services and browser operations use test doubles.
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_KEY", "test-db-key")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "")
    monkeypatch.setenv("OPEN_ROUTER_API_KEY", "private-model-key-do-not-log")
    monkeypatch.setenv("CORS_ORIGINS", "")
    import main

    server = importlib.reload(main)
    dao = Mock()
    dao.get_recipe.return_value = None
    dao.get_user_limit.return_value = 10
    dao.count_recipes.return_value = 0
    dao.insert.return_value = "test-recipe-id"
    monkeypatch.setattr(server, "get_db_client", Mock())
    monkeypatch.setattr(server, "RecipeDao", Mock(return_value=dao))
    monkeypatch.setattr(server, "validate_public_url", Mock())
    page = SimpleNamespace(
        route=AsyncMock(),
        goto=AsyncMock(),
        wait_for_load_state=AsyncMock(),
        content=AsyncMock(return_value=f"<p>{PRIVATE_TEXT}</p>"),
        close=AsyncMock(),
    )
    browser = SimpleNamespace(new_page=AsyncMock(return_value=page))
    monkeypatch.setattr(server, "get_browser", AsyncMock(return_value=browser))
    post = Mock(return_value=model_response())
    monkeypatch.setattr(recipe_extractor.requests, "post", post)
    monkeypatch.setattr(recipe_extractor.extract_recipe.retry, "sleep", Mock())
    return SimpleNamespace(server=server, dao=dao, page=page, post=post)


def test_save_times_page_model_and_database_without_private_data(import_server, capsys):
    deps = import_server
    with TestClient(deps.server.app) as client:
        response = client.get(
            "/get-recipe/" + requests.utils.quote(PRIVATE_URL, safe=""),
            headers={"auth-header": "Bearer private-user-token-do-not-log"},
        )
    assert response.status_code == 200
    assert response.json() == "Successfully inserted Recipe ID=test-recipe-id"
    output = capsys.readouterr().out
    records = timing_records(output)
    assert [r["stage"] for r in records] == [
        "db_client",
        "url_validation",
        "db_duplicate_lookup",
        "db_limit_lookup",
        "db_recipe_count",
        "browser_ready",
        "page_create",
        "page_navigation",
        "page_load_wait",
        "page_content",
        "page_close",
        "page_parse",
        "page_read",
        "page_to_text",
        "model_attempt",
        "model_total",
        "db_insert",
        "save_total",
    ]
    assert len({r["request_id"] for r in records}) == 1
    assert all(r["duration_ms"] >= 0 and r["status"] == "ok" for r in records)
    assert records[-1]["result"] == "saved"
    assert all(r["elapsed_ms"] <= records[-1]["elapsed_ms"] for r in records)
    attempt = next(r for r in records if r["stage"] == "model_attempt")
    assert attempt["model"] == recipe_extractor.MODEL_PRIMARY
    assert attempt["attempt"] == 1
    assert attempt["http_status"] == 200
    assert attempt["prompt_tokens"] == 123
    assert attempt["completion_tokens"] == 45
    assert attempt["page_chars"] > 0
    for private_value in [
        PRIVATE_TEXT,
        PRIVATE_URL,
        "private-model-key-do-not-log",
        "private-user-token-do-not-log",
    ]:
        assert private_value not in output
    deps.post.assert_called_once()
    deps.dao.insert.assert_called_once()
    deps.page.close.assert_awaited_once()
    assert deps.page.goto.await_args.kwargs == {
        "wait_until": "domcontentloaded",
        "timeout": 60000,
    }
    deps.page.wait_for_load_state.assert_awaited_once_with("load", timeout=5000)


def test_existing_recipe_skips_page_and_model(import_server, capsys):
    deps = import_server
    deps.dao.get_recipe.return_value = {"user_id": "test-user", "recipe_id": "test-id"}
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 200
    records = timing_records(capsys.readouterr().out)
    assert records[-1]["result"] == "already_saved"
    assert [r["stage"] for r in records] == [
        "db_client",
        "url_validation",
        "db_duplicate_lookup",
        "save_total",
    ]
    deps.server.get_browser.assert_not_called()
    deps.post.assert_not_called()
    deps.dao.insert.assert_not_called()


@pytest.mark.parametrize(
    "case,status", [("auth", 401), ("limit", 409), ("not_configured", 503)]
)
def test_early_errors_still_record_total(
    import_server, monkeypatch, capsys, case, status
):
    deps = import_server
    if case == "auth":
        deps.server.get_db_client.side_effect = HTTPException(401, PRIVATE_TEXT)
    elif case == "limit":
        deps.dao.count_recipes.return_value = 10
    else:
        monkeypatch.setenv("OPEN_ROUTER_API_KEY", "")
    with TestClient(deps.server.app) as client:
        assert (
            client.get("/get-recipe/https://example.com/recipe").status_code == status
        )
    output = capsys.readouterr().out
    total = timing_records(output)[-1]
    assert total["stage"] == "save_total"
    assert total["status"] == "error"
    assert total["http_status"] == status
    assert PRIVATE_TEXT not in output
    deps.server.get_browser.assert_not_called()
    deps.post.assert_not_called()


def test_failed_navigation_records_failure_and_closes_page(import_server, capsys):
    deps = import_server
    deps.page.goto.side_effect = PlaywrightTimeoutError(PRIVATE_URL)
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 400
    output = capsys.readouterr().out
    records = timing_records(output)
    navigation = next(r for r in records if r["stage"] == "page_navigation")
    assert navigation["status"] == "error"
    assert navigation["error_type"] == "TimeoutError"
    assert records[-1]["http_status"] == 400
    assert PRIVATE_URL not in output
    deps.page.close.assert_awaited_once()
    deps.post.assert_not_called()
    deps.dao.insert.assert_not_called()


def test_optional_page_load_timeout_does_not_fail_save(import_server, capsys):
    deps = import_server
    deps.page.wait_for_load_state.side_effect = PlaywrightTimeoutError(PRIVATE_URL)
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 200
    records = timing_records(capsys.readouterr().out)
    wait = next(r for r in records if r["stage"] == "page_load_wait")
    assert wait["status"] == "timeout_ignored"
    assert records[-1]["status"] == "ok"


@pytest.mark.parametrize("succeeds", [True, False])
def test_attempt_numbers_and_request_id_survive_fallback(
    import_server, capsys, succeeds
):
    deps = import_server
    responses = [model_response(status=503), model_response(status=503)]
    responses += (
        [model_response()]
        if succeeds
        else [model_response(status=503), model_response(status=503)]
    )
    deps.post.side_effect = responses
    with TestClient(deps.server.app) as client:
        response = client.get("/get-recipe/https://example.com/recipe")
    assert response.status_code == (200 if succeeds else 503)
    output = capsys.readouterr().out
    records = timing_records(output)
    attempts = [r for r in records if r["stage"] == "model_attempt"]
    assert [r["attempt"] for r in attempts] == list(range(1, len(responses) + 1))
    assert [r["model"] for r in attempts[:2]] == [recipe_extractor.MODEL_PRIMARY] * 2
    assert all(r["model"] == recipe_extractor.MODEL_FALLBACK for r in attempts[2:])
    assert len({r["request_id"] for r in records}) == 1
    assert deps.post.call_count == len(responses)
    assert all(r["status"] == "error" for r in attempts[:2])
    assert attempts[-1]["status"] == ("ok" if succeeds else "error")
    assert PRIVATE_TEXT not in output
    if not succeeds:
        deps.dao.insert.assert_not_called()


def test_model_total_includes_retry_wait(import_server, monkeypatch, capsys):
    deps = import_server
    clock = [0.0]
    calls = []
    monkeypatch.setattr(recipe_timing, "perf_counter", lambda: clock[0])

    def post(**kwargs):
        calls.append(kwargs)
        clock[0] += 1.0
        if len(calls) == 1:
            raise requests.Timeout(PRIVATE_TEXT)
        return model_response()

    def sleep(seconds):
        clock[0] += seconds

    deps.post.side_effect = post
    monkeypatch.setattr(recipe_extractor.extract_recipe.retry, "sleep", sleep)
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 200
    output = capsys.readouterr().out
    records = timing_records(output)
    attempts = [r for r in records if r["stage"] == "model_attempt"]
    assert [r["duration_ms"] for r in attempts] == [1000, 1000]
    assert attempts[0]["error_type"] == "Timeout"
    assert attempts[1]["status"] == "ok"
    assert all(r["model"] == recipe_extractor.MODEL_PRIMARY for r in attempts)
    total = next(r for r in records if r["stage"] == "model_total")
    assert total["duration_ms"] == 4000  # Two calls plus the existing two-second wait.
    assert all(call["timeout"] == 60 for call in calls)
    assert PRIVATE_TEXT not in output


def test_unexpected_usage_fields_do_not_change_model_result(import_server, capsys):
    deps = import_server
    body = model_response().json()
    body["usage"] = {"prompt_tokens": PRIVATE_TEXT, "completion_tokens": True}
    deps.post.return_value = model_response(body=body)
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 200
    output = capsys.readouterr().out
    attempt = next(r for r in timing_records(output) if r["stage"] == "model_attempt")
    assert "prompt_tokens" not in attempt
    assert "completion_tokens" not in attempt
    assert PRIVATE_TEXT not in output


@pytest.mark.parametrize(
    "body",
    [
        {"error": {"message": PRIVATE_TEXT}},
        {"choices": [{"finish_reason": "stop", "message": {"content": PRIVATE_TEXT}}]},
    ],
)
def test_invalid_model_response_does_not_log_body(import_server, capsys, body):
    deps = import_server
    deps.post.return_value = model_response(body=body)
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 503
    output = capsys.readouterr().out
    attempt = next(r for r in timing_records(output) if r["stage"] == "model_attempt")
    assert attempt["status"] == "invalid_response"
    assert PRIVATE_TEXT not in output
    deps.post.assert_called_once()
    deps.dao.insert.assert_not_called()


def test_no_recipe_keeps_422_and_does_not_insert(import_server, capsys):
    deps = import_server
    deps.post.return_value = model_response(recipe={"no_recipe": True})
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 422
    records = timing_records(capsys.readouterr().out)
    assert records[-1]["http_status"] == 422
    deps.dao.insert.assert_not_called()


def test_database_failure_records_total(import_server, capsys):
    deps = import_server
    deps.dao.insert.side_effect = RuntimeError(PRIVATE_TEXT)
    with TestClient(deps.server.app, raise_server_exceptions=False) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 500
    output = capsys.readouterr().out
    records = timing_records(output)
    assert records[-2]["stage"] == "db_insert"
    assert records[-2]["error_type"] == "RuntimeError"
    assert records[-1]["stage"] == "save_total"
    assert records[-1]["status"] == "error"
    assert PRIVATE_TEXT not in output


def test_cookbook_loading_has_no_import_timings(import_server, capsys):
    deps = import_server
    deps.dao.get_recipes.return_value = []
    with TestClient(deps.server.app) as client:
        assert client.get("/get-all-recipes").json() == []
    assert timing_records(capsys.readouterr().out) == []


def test_duration_uses_monotonic_clock(monkeypatch, capsys):
    clock = iter([10.0, 10.0, 11.0, 12.5, 14.0])
    monkeypatch.setattr(recipe_timing, "perf_counter", lambda: next(clock))
    with time_recipe_save():
        with timed_step("page_read"):
            pass
    page, total = timing_records(capsys.readouterr().out)
    assert page["duration_ms"] == 1500
    assert page["elapsed_ms"] == 2500
    assert total["duration_ms"] == 4000


def test_parallel_imports_have_separate_ids_and_attempt_counts(capsys):
    async def save():
        with time_recipe_save():
            await asyncio.sleep(0)
            with timed_step("model_attempt"):
                await asyncio.sleep(0)
            with timed_step("model_attempt"):
                await asyncio.sleep(0)

    async def run():
        await asyncio.gather(save(), save())
        with timed_step("outside_import"):
            pass

    asyncio.run(run())
    records = timing_records(capsys.readouterr().out)
    totals = [r for r in records if r["stage"] == "save_total"]
    assert len(totals) == 2
    assert totals[0]["request_id"] != totals[1]["request_id"]
    for total in totals:
        attempts = [
            r["attempt"]
            for r in records
            if r["request_id"] == total["request_id"] and r["stage"] == "model_attempt"
        ]
        assert attempts == [1, 2]
    assert not any(r["stage"] == "outside_import" for r in records)


def test_save_uses_browser_and_sends_full_page_text(import_server, capsys):
    deps = import_server
    html = """<html><body><nav>Navigation text</nav><article>
      <h1>Vegetable supper</h1><div class="wprm-recipe-container">
      <h2 class="wprm-recipe-name">Vegetable supper</h2>
      <p class="wprm-recipe-ingredient">1 tomato</p>
      <p class="wprm-recipe-instruction-text">Cook the tomato gently.</p>
      </div></article><p>Notes outside the recipe article.</p>
      <footer>Footer text</footer></body></html>"""
    deps.page.content.return_value = html
    converter = html2text.HTML2Text()
    converter.ignore_links = True
    full_text = converter.handle(str(BeautifulSoup(html, "html.parser")))
    with TestClient(deps.server.app) as client:
        response = client.get("/get-recipe/https://example.com/recipe")
    assert response.status_code == 200
    assert response.json() == "Successfully inserted Recipe ID=test-recipe-id"
    deps.server.get_browser.assert_awaited_once()
    deps.page.goto.assert_awaited_once()
    deps.post.assert_called_once()
    call = deps.post.call_args.kwargs
    assert json.loads(call["data"]) == {
        "model": recipe_extractor.MODEL_PRIMARY,
        "max_tokens": 5000,
        "messages": [
            {
                "role": "user",
                "content": recipe_extractor.RECIPE_EXTRACTION_PROMPT + "\n" + full_text,
            }
        ],
    }
    assert "Navigation text" in full_text
    assert "Notes outside the recipe article" in full_text
    assert "Footer text" in full_text
    assert call["url"] == "https://openrouter.ai/api/v1/chat/completions"
    assert call["timeout"] == 60
    assert call["headers"] == {
        "Authorization": "Bearer private-model-key-do-not-log",
        "Content-Type": "application/json",
    }
    saved = deps.dao.insert.call_args.args[0]
    assert saved.public_url == "https://example.com/recipe"
    assert saved.recipe_json == {
        "recipe_name": PRIVATE_TEXT,
        "ingredients": ["1 tomato"],
    }
    output = capsys.readouterr().out
    records = timing_records(output)
    text = next(r for r in records if r["stage"] == "page_to_text")
    assert text["page_chars"] == len(full_text)
    assert not any(r["stage"] == "plain_fetch" for r in records)
    assert "Vegetable supper" not in output
    assert PRIVATE_TEXT not in output


def test_security_rejection_does_not_start_browser_or_model(import_server, capsys):
    deps = import_server
    deps.server.validate_public_url.side_effect = HTTPException(400, PRIVATE_URL)
    with TestClient(deps.server.app) as client:
        assert client.get("/get-recipe/https://example.com/recipe").status_code == 400
    deps.server.get_browser.assert_not_called()
    deps.post.assert_not_called()
    deps.dao.insert.assert_not_called()
    output = capsys.readouterr().out
    assert PRIVATE_URL not in output
    records = timing_records(output)
    assert len({record["request_id"] for record in records}) == 1
    assert records[-1]["http_status"] == 400


def test_browser_guards_initial_redirect_and_resource_requests(
    import_server, monkeypatch
):
    deps = import_server
    guard_host = Mock(side_effect=lambda host: host != "public.example.com")
    monkeypatch.setattr(deps.server.url_extractor, "is_blocked_host", guard_host)
    with TestClient(deps.server.app) as client:
        assert (
            client.get("/get-recipe/https://public.example.com/recipe").status_code
            == 200
        )
    pattern, guard = deps.page.route.await_args.args
    assert pattern == "**/*"
    for url, blocked in [
        ("https://public.example.com/recipe", False),
        ("http://127.0.0.1/redirect", True),
        ("http://169.254.169.254/resource", True),
    ]:
        route = SimpleNamespace(
            request=SimpleNamespace(url=url), abort=AsyncMock(), continue_=AsyncMock()
        )
        asyncio.run(guard(route))
        assert route.abort.await_count == int(blocked)
        assert route.continue_.await_count == int(not blocked)


def test_cancellation_logs_and_clears_context(capsys):
    with pytest.raises(asyncio.CancelledError):
        with time_recipe_save():
            with timed_step("page_read"):
                raise asyncio.CancelledError()
    with timed_step("outside_import"):
        pass
    records = timing_records(capsys.readouterr().out)
    assert len(records) == 2
    assert all(r["error_type"] == "CancelledError" for r in records)
    assert all(r["status"] == "error" for r in records)
