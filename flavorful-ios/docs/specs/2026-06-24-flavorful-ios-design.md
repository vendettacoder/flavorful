# Flavorful iOS (Flutter) — Design

_Date: 2026-06-24 · Source of truth: `design_handoff_flutter_ios/README.md` + the
right-column iOS frames in `Flavorful.dc.html`._

## Goal

Recreate the four iOS mockups (Sign in, Library, Library-saving, Recipe detail)
in Flutter, pixel-close to the handoff tokens, runnable today without a backend.

## Decisions (approved)

1. **Toolchain** — install Flutter SDK now; author + analyze + test on host.
   Xcode (for the iOS simulator) is the user's separate install.
2. **API** — target the real backend (`/login` Bearer, `/get-all-recipes`,
   `/extract-recipe/{url}`, `/get-recipe/{id}`, Supabase auth). Delete + favorite
   have no endpoint yet → stubbed client-side.
3. **Data layer** — `RecipeRepository` interface with an in-memory mock (default)
   so the app runs standalone; HTTP impl behind the same interface.
4. **State** — Riverpod.

Cross-cutting: keep it simple/maintainable — plain immutable models (no
codegen), `Navigator` (no router package), minimal dependencies.

## Architecture

Layered: `theme` (tokens) → `models` → `util` → `data` (repositories) →
`providers` (Riverpod) → `widgets` → `screens` → `main`. The UI depends only on
`RecipeRepository`/`AuthRepository`, so mock and live implementations are
swapped via one provider (`AppConfig.useMockData`).

## Screens

- **Sign in** — green hero + beige sheet, single Continue-with-Google button;
  light status bar. Mock auth returns a session; real flow (Google SSO via
  Supabase → `/login`) drops in behind `AuthRepository`.
- **Library** — top bar (wordmark + avatar), title block, URL paste field, card
  list with pull-to-refresh and an empty state. Dark status bar.
- **Library (saving)** — same screen; the add-recipe flow drives the
  "SAVING RECIPE" eyebrow, the focused field with the pasted URL, a
  "Fetching recipe…" spinner row, success prepend (200ms slide-in), and a
  retryable error row.
- **Recipe detail** — Original-page CTA, title block, stats (time / servings
  stepper / difficulty), Ingredients (checkoff + servings scaling), Method,
  Notes. Favorite toggle + delete (confirm dialog).

## Behavior notes

- Servings scaling multiplies `Ingredient.quantityValue` and renders mixed
  fractions (`util/fractions.dart`). Stepper clamped 1..24.
- Ingredient checkoff is in-memory per cook session (resets on open).
- Status bar style per screen via `AnnotatedRegion`. Light mode forced.

## Fonts

Geist + Geist Mono bundled under `fonts/` (SIL OFL). `google_fonts` was dropped:
its 6.x catalog doesn't include Geist, so `getFont('Geist')` throws — bundling is
correct, deterministic, and offline-safe.

## Testing

Unit: fraction formatting, servings scaling, hostname parsing. Widget: stepper,
checkbox, recipe card, and a Library smoke test against the mock repo.

## Out of scope (v1)

Editing, sharing, collections/tags, search, shopping list, image storage,
Android polish, web app.
