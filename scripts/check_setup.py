"""Check hosted Supabase access without reading recipe rows or changing data."""

import os
from pathlib import Path

import requests
from dotenv import load_dotenv


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    load_dotenv(ROOT / ".env")
    url = os.getenv("SUPABASE_URL", "").rstrip("/")
    key = os.getenv("SUPABASE_KEY", "")
    if not url or not key:
        print("FAIL: Set SUPABASE_URL and SUPABASE_KEY in .env.")
        return 1

    checks = [
        ("Supabase sign-in service", "/auth/v1/settings", {}),
        (
            "recipe_db columns",
            "/rest/v1/recipe_db",
            {
                "select": "recipe_id,user_id,public_url,recipe_metadata,is_favorited,created_at",
                "limit": "0",
            },
        ),
        (
            "user_limits columns",
            "/rest/v1/user_limits",
            {"select": "user_id,recipe_limit", "limit": "0"},
        ),
    ]
    failed = False
    with requests.Session() as session:
        session.headers.update({"apikey": key})
        for label, path, params in checks:
            try:
                response = session.get(
                    url + path, params=params, timeout=20, allow_redirects=False
                )
            except requests.RequestException:
                print(f"FAIL: {label}: connection failed.")
                failed = True
                continue
            if response.status_code == 200:
                print(f"PASS: {label}.")
            else:
                print(f"FAIL: {label}: HTTP {response.status_code}.")
                failed = True

    print("These checks do not prove signed-in user access or account access.")
    print("These checks do not read recipe rows or test writes.")
    for name, purpose in [
        ("OPEN_ROUTER_API_KEY", "recipe extraction"),
        ("SUPABASE_SERVICE_ROLE_KEY", "account deletion"),
    ]:
        if os.getenv(name, "").strip():
            print(f"SET: {name} for {purpose}. Value not tested.")
        else:
            print(f"MISSING: {name} for {purpose}.")
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
