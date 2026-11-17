# Local server with hosted Supabase

Run the Python server on this Mac. Use the existing Supabase project for sign-in and recipe storage. Do not install Flutter or Xcode for this setup.

**This setup uses live data.** Saving or deleting a recipe changes the hosted database. Do not use account deletion as a test.

## Install and start

Install [uv](https://docs.astral.sh/uv/) first. Then run these commands from the project directory:

```sh
make setup
cp -n .env.example .env
```

Edit `.env`. Set these values from Supabase **Project Settings → API**:

- `SUPABASE_URL`: the project URL.
- `SUPABASE_KEY`: the publishable key or the legacy anon key. Do not use the service-role key here.

The existing project is `olqukyolwuzsncoreute`. Its public settings also appear in `flavorful-ios/lib/config.dart`.

Set `OPEN_ROUTER_API_KEY` to use recipe extraction. Get a key from https://openrouter.ai/settings/keys. Without this key, the server can list existing recipes after sign-in. It returns HTTP 503 when asked to extract a new recipe.

`SUPABASE_SERVICE_ROLE_KEY` is only needed to delete a Supabase user. Keep it on the server. Never put it in browser code. The account deletion route can delete recipes even when this key is absent.

Protect the local file:

```sh
chmod 600 .env
```

Start the server:

```sh
make dev
```

- Server: http://127.0.0.1:8001
- API documentation: http://127.0.0.1:8001/docs
- Health check: http://127.0.0.1:8001/

The server accepts connections from this Mac only. It reloads Python code when a file changes. Stop it with Ctrl+C. Restart it after you change `.env`.

To use another port:

```sh
make dev PORT=8002
```

Docker is not needed for this setup.

## Check the setup

```sh
make check
make test
```

`make check` contacts Supabase. It checks the sign-in service and the required table columns. It requests zero recipe rows. It does not change data. It reports missing optional keys without showing key values.

This check does not prove signed-in user access, account access, or write access. It does not test OpenRouter. `make test` uses no hosted services.

The `/` health check only shows that the Python server responds. It does not check Supabase or OpenRouter.

## Recipe save timings

The server writes one JSON timing record when each save step ends. These records apply only to `/get-recipe/{url}`. Cookbook loading is unchanged.

Each record has `event: "recipe_timing"`, a `request_id`, a `stage`, a `status`, and a `duration_ms`. All records for one save use the same request ID. `elapsed_ms` measures time since that save started.

Use these stages to find delays:

| Stage | What it measures |
| --- | --- |
| `url_validation` | URL format and public-address checks before reading the page. |
| `browser_ready` | Getting the browser, including startup when needed. |
| `page_read` | The complete browser page read, including page creation and HTML parsing. |
| `page_navigation` | Loading the page until its initial HTML and scripts are ready. |
| `page_load_wait` | The extra wait for the page load event. The limit remains five seconds. |
| `page_to_text` | Converting the HTML to the text sent to the model. |
| `model_attempt` | One model request and response parsing. |
| `model_total` | All model attempts, including retry waits and the fallback model. |
| `db_*` | Database work within the save request. |
| `save_total` | The complete save handler, including failed saves and existing recipes. |

`model_attempt` records include the model name and attempt number. Attempt numbers continue across the fallback model. They also include input character counts and token counts when the provider supplies them.

`page_to_text` includes `page_chars`, the number of page-text characters sent to the model. It does not include the text itself.

Nested timings overlap. Do not add `page_read` to its page steps. `browser_ready` is separate from `page_read`. Do not add `model_total` to its attempts. `save_total` already includes these steps. It does not include later cookbook requests or time before the handler starts.

Errors include the exception type, not the exception message. A `page_load_wait` record with `status: "timeout_ignored"` means the server continued after the optional wait. Timing records omit URLs, user IDs, credentials, page text, and model output. Existing HTTP access logs can still contain URLs.

When server output is saved in `.local/server.log`, show the timing records with:

```sh
grep '"event": "recipe_timing"' .local/server.log
```

These logs do not change the model, retry policy, browser page waits, or API responses.

## Recipe page reads

The server reads recipe pages with Playwright. It does not try a separate plain HTML read first. It checks the input URL and each browser request for private or internal addresses.

The server converts the whole page to text with `html2text`. It sends that text to the existing model. It does not select a smaller recipe section or remember failed plain reads.

The tests use HTML, network, model, and database doubles. They block external network calls and do not load `.env`.

## Supabase account access

Install the command if needed:

```sh
brew install supabase/tap/supabase
```

Sign in on a new Mac:

```sh
supabase login
supabase projects list
```

Complete the browser sign-in and any verification-code prompt in the terminal. You do not need credentials from an old Mac. The command stores the new account login locally. This account login is separate from the keys in `.env`.

From the project directory, link this copy to the existing project:

```sh
supabase link --project-ref olqukyolwuzsncoreute --skip-pooler
```

This saves local project settings. It does not change the database. Git ignores these settings in `supabase/.temp/`.

Open the project dashboard:

https://supabase.com/dashboard/project/olqukyolwuzsncoreute

Do not run `db push`, `db reset`, or other database-changing commands during setup.

## Fly.io access

The existing server uses Fly.io. `fly.toml` names the app `flavorful` in region `ewr`. The hosted server is https://flavorful.fly.dev.

You do not need Fly.io to run the Python server locally. To manage the existing app from this Mac:

```sh
brew install flyctl
flyctl auth login
flyctl auth whoami
flyctl status --app flavorful
flyctl secrets list --app flavorful
```

These checks do not deploy code. `flyctl secrets list` shows secret names, not their values. A Fly.io login does not copy the server's secrets into `.env`.

If you reuse the hosted OpenRouter key locally, local extraction uses the same account balance. Never print the key into a shared terminal log. Keep it in the ignored `.env` file.

Do not run `flyctl launch` for the existing app. Do not run `flyctl deploy` or `flyctl secrets set` unless you intend to change the hosted server.

## Future web interface

Set the web interface's API URL to `http://127.0.0.1:8001`.

The example `.env` allows browser requests from these exact origins:

- `http://localhost:3000`
- `http://127.0.0.1:3000`
- `http://localhost:5173`
- `http://127.0.0.1:5173`

Change `CORS_ORIGINS` if the web interface uses another origin. Separate origins with commas. Do not use `*`. If the variable is empty or absent, the server does not allow requests from a separate browser origin. The hosted server keeps its existing behavior until you set this variable there.

Use the Supabase URL and publishable key in the web interface. Sign in through Supabase. Send the user's access token to the Python server with the existing header:

```text
auth-header: Bearer <user-access-token>
```

The project uses `auth-header`, not `Authorization`. A publishable key alone is not a user's access token.

For Google or Apple sign-in, check **Supabase → Authentication → URL Configuration**. The web interface's callback URL must appear in the allowed redirect URLs. Do not replace the current site URL or remove existing redirects. Adding a redirect changes hosted settings. This setup does not change them.

No web interface is included in this setup. The API documentation page is available for server checks.
