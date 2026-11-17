# Shared Flutter web app

The Dart app in `lib/` is the design reference for iPhone and web.
Do not use the old HTML designs or the old frontend spec.
The web app uses the same fonts, colors, recipe cards, and Save form as iPhone.

## Run on this Mac

Use Flutter 3.50.0 and Dart 3.14.0.
Run these commands from the repository root:

```sh
make web
make web-test
make web-build
```

`make web` serves the live app at http://127.0.0.1:5173.
It uses the local API at http://127.0.0.1:8001.
Run the backend separately with `make dev`.
Live sign-in contacts Supabase and Google.
Saving a recipe in live mode can use a paid extraction service.

Set `FLUTTER=/path/to/flutter` if the SDK is not at `~/development/flutter/bin/flutter`.
Set `API_BASE_URL` for a different development API.
Set `WEB_API_BASE_URL` for a different release API.

```sh
make web API_BASE_URL=http://127.0.0.1:8001
make web-build WEB_API_BASE_URL=https://your-api.example
```

`API_BASE_URL` overrides both development and production defaults.
Without an override, browser development uses port 8001.
Native development still uses `http://localhost:8000`.
Production defaults to `https://flavorful.fly.dev`.
No server or admin keys belong in Dart or web files.

## Offline demo

```sh
make web-demo
```

This builds with `--dart-define=FLAVORFUL_MOCK=true`.
It serves only `flavorful-ios/build/web-demo` at http://127.0.0.1:5173.
The banner says **Offline demo · Sample data only**.
Google sign-in creates a sample session without a network request.
Save creates sample recipes without reading the page or calling the API.
The sample session and recipe changes reset on refresh.
A protected recipe URL asks for mock sign-in again after refresh.

The demo includes fonts and browser drawing files locally.
It does not initialize Supabase.
Source and Privacy Policy links still open external pages if selected.
Do not select those links during a fully offline check.
The offline demo is not a live sign-in or extraction test.
Mock mode is never the default.
Its separate build directory does not replace the live build.

To serve a build that already exists:

```sh
python3 flavorful-ios/tool/serve_web.py --demo --port 5173
```

Stop the server with Ctrl+C before starting another server on port 5173.
The server binds to `127.0.0.1` only.
It never serves the repository root or `.env`.

## Sign-in and routes

This web version offers **Google only**.
The native app keeps Apple and Google sign-in.
Apple web sign-in needs a configured OAuth secret before it can be offered.
The first web version does not offer it.

The browser callback is the current origin plus `/auth/callback`.
Supabase performs the authorization-code exchange.
The app does not parse access tokens.
A successful callback removes its query from the browser URL.
The app returns to the requested local recipe or to the cookbook.
The callback screen shows a retry path if sign-in fails.

Local sign-in needs these Supabase redirect entries:

- `http://127.0.0.1:5173/auth/callback`
- `http://localhost:5173/auth/callback`

Check Google sign-in and session restoration in a live browser.
Offline tests do not verify either flow.
Do not change hosted settings without approval.

Routes:

- `/`: cookbook
- `/recipes/:id`: recipe detail
- `/sign-in`: sign-in
- `/auth/callback`: browser sign-in result
- Other paths: page not found

The hosting server must serve `index.html` for app routes.
It must serve real static files without rewriting their paths.
The local helper includes this route fallback.
A production host also needs HTTPS and its exact Supabase callback entry.
A separate API origin also needs explicit backend CORS.
Do not cache `index.html` or `flutter_bootstrap.js` without revalidation.

## Deploy to Fly.io

The web app and API use `https://flavorful.fly.dev`.
The server serves the compiled app from `/app/web`.
API routes keep their existing paths.
Use `/health` for the server health response.
Local API-only runs also keep the health response at `/`.

Commit and push changes before running this command from the repository root:

```sh
make deploy
```

The command requires a clean working directory.
It builds the live web app from the current Git commit in a temporary directory.
It deploys that web build and the API from the same commit.
It does not run native iOS tests or deploy the offline demo.
It keeps the existing Fly machine and public IPs.
Fly supplies the existing server secrets.
Do not use a bare `fly deploy` without preparing the web build.

Supabase must allow `https://flavorful.fly.dev/auth/callback`.
Keep existing native and local callback entries.
The shared origin does not need a new CORS entry.

## Layout and tests

The cookbook has one column below 700 pixels, two from 700 pixels, and three from 1100 pixels.
Its content width is at most 1180 pixels.
Recipe detail uses two columns from 850 pixels and at most 1100 pixels overall.
The description is at most 680 pixels wide.
Short windows scroll the form and content.
Keyboard users can reach custom controls with Tab and activate them with Enter or Space.

`make web-test` runs analysis and offline widget/unit tests.
Tests cover routes, callback cleanup, user changes, token refresh, search, responsive sizes, scaling, checkoff, save retry, and partial account deletion.
`make web-build` builds JavaScript output without deployment.
Flutter reports a WebAssembly dry-run warning for the locked `ua_client_hints` dependency.
The JavaScript build works.
No native signing changes are needed.

The locked Supabase package also needs a local JavaScript file at startup.
See `web/vendor/README.md` for its exact source, license, and checksum.
