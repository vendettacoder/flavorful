# Flavorful

An iOS-first recipe keeper. Paste a food-blog URL; the backend scrapes the page,
an AI model extracts the structured recipe, and you browse and cook from your
saved cookbook.

## Architecture

```
┌─────────────────┐        HTTPS         ┌──────────────────────┐
│  Flutter iOS app │ ───────────────────▶ │  FastAPI backend      │
│  (flavorful-ios) │  auth-header: Bearer │  (main.py, on Fly.io) │
└────────┬─────────┘   <supabase token>   └──────────┬───────────┘
         │                                            │
         │ Supabase Google/Apple OAuth                │ Playwright scrape
         │ (session + access token)                   │ + OpenRouter LLM extract
         ▼                                            ▼
┌─────────────────────────────┐          ┌──────────────────────────┐
│  Supabase (auth + Postgres) │◀─────────│  OpenRouter (Gemini/GPT)  │
│  RLS-scoped recipe rows      │  writes  │  structured JSON extract  │
└─────────────────────────────┘          └──────────────────────────┘
```

- **Backend** — Python 3.14 / FastAPI, headless Chromium via Playwright, deployed on Fly.io.
- **Database + auth** — Supabase (Postgres with Row-Level Security; Google + Apple OAuth).
- **AI extraction** — OpenRouter, routing to `google/gemini-3.1-flash-lite` (primary) and `openai/gpt-4.1-nano` (fallback).
- **App** — Flutter (Riverpod), targeting iOS.

## Repository layout

```
.
├── main.py                 # FastAPI app + routes
├── recipe_dao.py           # Supabase data access (RLS-scoped)
├── recipe_extractor.py     # OpenRouter LLM extraction
├── url_extractor.py        # Playwright page fetch
├── url_safety.py           # SSRF guard for user-supplied URLs
├── Dockerfile              # Backend container (FastAPI + Chromium)
├── fly.toml                # Fly.io app config
├── pyproject.toml / uv.lock # Python deps (uv)
├── .env                    # Backend secrets (gitignored — see below)
└── flavorful-ios/          # Flutter app
    ├── lib/                # Dart source
    ├── ios/                # Xcode project (Runner)
    └── test/               # Widget + unit tests
```

## Prerequisites

- [uv](https://docs.astral.sh/uv/) (Python package manager) + Python 3.14
- [Flutter](https://flutter.dev) SDK + Xcode 26 (iOS 26 SDK) for the app
- [flyctl](https://fly.io/docs/flyctl/) for backend deploys
- A [Supabase](https://supabase.com) project and an [OpenRouter](https://openrouter.ai) API key

## Secrets

The backend reads four environment variables. Locally they live in `.env`
(**gitignored — never commit it**); in production they are Fly.io secrets.

| Variable | What it is | Where to get it |
|---|---|---|
| `SUPABASE_URL` | Project URL, e.g. `https://xxxx.supabase.co` | Supabase → Project Settings → API |
| `SUPABASE_KEY` | Anon/publishable key (RLS-scoped client) | Supabase → Project Settings → API |
| `SUPABASE_SERVICE_ROLE_KEY` | Service-role key — used only to delete auth users on account deletion | Supabase → Project Settings → API (keep secret!) |
| `OPEN_ROUTER_API_KEY` | OpenRouter API key for recipe extraction | OpenRouter → Keys |

Local `.env` template:

```dotenv
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_KEY=YOUR-ANON-KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR-SERVICE-ROLE-KEY
OPEN_ROUTER_API_KEY=YOUR-OPENROUTER-KEY
```

> The Flutter app's Supabase URL + **publishable** key are compiled into
> `flavorful-ios/lib/config.dart` (client-safe by design). The service-role key
> is **backend-only** and must never ship in the app.

## Backend — local development

```bash
# 1. Install dependencies (creates .venv from uv.lock)
uv sync

# 2. Install the Chromium browser Playwright drives
uv run playwright install chromium

# 3. Run the dev server (hot reload) on http://localhost:8000
uv run fastapi dev main.py
```

Health check: `curl http://localhost:8000/` → `{"status":"ok"}`.

Key endpoints (all require `auth-header: Bearer <supabase_access_token>`):

| Method | Path | Purpose |
|---|---|---|
| GET | `/get-all-recipes` | List the caller's recipes (favorites first, newest first) |
| GET | `/get-recipe/{url}` | Scrape + extract + save a recipe (rate-limited) |
| GET | `/search-recipes?q=` | Search by recipe name |
| POST | `/favorite-recipe/{id}` | Toggle favorite |
| DELETE | `/delete-recipe/{id}` | Delete one recipe |
| DELETE | `/delete-account` | Wipe the caller's data + Supabase auth user |

Run the tests:

```bash
uv run pytest
```

## Backend — deploy to Fly.io

The app is named `flavorful` (region `ewr`), scale-to-zero enabled. First-time setup:

```bash
# Authenticate once
fly auth login

# (First deploy only) create the app without deploying
fly launch --no-deploy --name flavorful --region ewr   # skip if app already exists
```

Load the secrets into Fly (this sets them as encrypted env vars, then triggers a
redeploy). Run once, and again whenever a secret rotates:

```bash
fly secrets set \
  SUPABASE_URL="https://YOUR-PROJECT.supabase.co" \
  SUPABASE_KEY="YOUR-ANON-KEY" \
  SUPABASE_SERVICE_ROLE_KEY="YOUR-SERVICE-ROLE-KEY" \
  OPEN_ROUTER_API_KEY="YOUR-OPENROUTER-KEY"
```

Deploy the current code (builds the Dockerfile, ships Chromium):

```bash
fly deploy
```

Useful ops commands:

```bash
fly logs                 # stream logs
fly secrets list         # names only (values are never shown)
fly status               # machine + health state
fly apps open            # open https://flavorful.fly.dev
```

> Chromium + Playwright boot lazily on the first scrape after a cold start, so
> the server binds the port immediately and Fly's proxy connects on wake.

## Flutter app — run and deploy

All commands run from `flavorful-ios/`.

```bash
cd flavorful-ios
flutter pub get
```

**Environment switch** — `lib/config.dart` chooses the backend by the
`FLAVORFUL_ENV` dart-define:

- `dev` (default): `http://localhost:8000` — works on the iOS **simulator** (localhost reaches the host).
- `prod`: `https://flavorful.fly.dev` — required for a **physical device** (localhost can't reach your Mac).

Run on a connected device (list devices first):

```bash
flutter devices
# Debug against the production backend on a physical iPhone:
flutter run --release -d <device-id> --dart-define=FLAVORFUL_ENV=prod
```

Build + install a release build without attaching a debugger:

```bash
flutter build ios --release --dart-define=FLAVORFUL_ENV=prod
flutter install --release -d <device-id>
```

- Bundle identifier: `com.flavorful.flavorful`
- Signing: automatic, Apple Developer team `99Z4NBW6F3` (set in the Xcode project)
- Icons are generated from `assets/icon/icon.png` via `flutter pub run flutter_launcher_icons`

Run the app tests:

```bash
flutter test
flutter analyze
```

## Supabase setup

The backend expects two RLS-protected tables:

- `recipe_db` — columns include `recipe_id`, `user_id`, `public_url`,
  `recipe_metadata` (jsonb), `is_favorited`, `created_at`. RLS scopes every row
  to `auth.uid()`.
- `user_limits` — optional per-user `recipe_limit` override (defaults to 10).

Auth: enable **Google** and **Apple** providers. Add the app's OAuth redirect
`flavorful://login-callback` to the Supabase Auth redirect allowlist (it is also
registered as a `CFBundleURLScheme` in `ios/Runner/Info.plist`).

## Privacy policy

Hosted separately on GitHub Pages from the [`flavorful-privacy`](https://github.com/vendettacoder/flavorful-privacy)
repo → https://vendettacoder.github.io/flavorful-privacy/ . The source is also in
`PRIVACY_POLICY.md`. Update both if data practices change.

## App Store submission notes

- Built with Xcode 26 / iOS 26 SDK.
- `Info.plist` declares `ITSAppUsesNonExemptEncryption=false` (HTTPS-only, exempt).
- `ios/Runner/PrivacyInfo.xcprivacy` declares collected data + Required-Reason APIs.
- Account deletion is in-app (Profile → Delete account), per Guideline 5.1.1(v).
- Sign in with Apple is offered alongside Google, per Guideline 4.8.
- Recipe pages are sent to an AI service (OpenRouter) — disclosed in-app on the
  sign-in screen and in the privacy policy.
- Availability excludes the EU (avoids the DSA trader-status requirement).
