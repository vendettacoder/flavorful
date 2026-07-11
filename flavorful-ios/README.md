# Flavorful — iOS app (Flutter)

An iOS-first recipe keeper. Sign in with Google, paste a food-blog URL, and the
backend scrapes the recipe; browse your library, scale servings, and check off
ingredients while cooking. Built to the design handoff in
`design_handoff_flutter_ios/` (the right-column iOS mockups).

This is **v1**: Sign in · Library · Add recipe (paste URL) · Recipe detail ·
favorite · delete. No images, editing, search, or collections yet.

## Status

- ✅ All four screens implemented pixel-close to the handoff tokens.
- ✅ Runs **fully against in-memory sample data** — no backend required.
- ✅ `flutter analyze` clean; `flutter test` green (23 tests).
- ⏳ Running on an iOS simulator/device needs **Xcode** (see below). The Dart
  code compiles and is fully tested on the host today.

## Requirements

- Flutter 3.44+ / Dart 3.12+ (installed at `~/development/flutter`).
- For iOS: **Xcode** (install from the App Store) + CocoaPods
  (`sudo gem install cocoapods` or `brew install cocoapods`). These are not yet
  installed on this machine.

## Run

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd dd/flavorful-ios
flutter pub get
flutter test          # unit + widget tests (no simulator needed)

# Once Xcode is installed:
open -a Simulator
flutter run            # launches on the booted iOS simulator
```

## Architecture

```
lib/
  config.dart              # useMockData flag + apiBaseUrl
  theme/tokens.dart        # colors, type (Geist), spacing, radii, shadows
  models/recipe.dart       # Recipe, Ingredient, NoteFromPage (+ tolerant JSON)
  util/fractions.dart      # decimal → mixed fraction (½, 1¼) for servings
  data/
    recipe_repository.dart       # interface the UI depends on
    mock_recipe_repository.dart  # in-memory sample data (default)
    http_recipe_repository.dart  # real backend (dio)
    auth_repository.dart         # interface + mock (Supabase later)
    sample_data.dart             # the 4 library cards + full lentil-soup detail
  providers/providers.dart # Riverpod: repos, auth, recipes, add-recipe, detail
  widgets/                 # RecipeCard, UrlPasteField, ServingsStepper, …, icons
  screens/                 # sign_in, library, recipe_detail
  main.dart                # ProviderScope + MaterialApp (light) + auth gate
```

State management is **Riverpod**. The UI depends only on `RecipeRepository`, so
the mock and the live HTTP client are interchangeable.

## Backend

`AppConfig.useMockData` (in `lib/config.dart`) selects the data source:

- `true` (default) → `MockRecipeRepository`, sample data, no network.
- `false` → `HttpRecipeRepository` against `AppConfig.apiBaseUrl`.

Endpoint map (the real backend), with `Authorization: Bearer <token>` on every
request:

| App action     | Endpoint                      |
|----------------|-------------------------------|
| Sign in        | Google SSO (Supabase) → `POST /login` |
| Load library   | `GET /get-all-recipes`        |
| Add recipe     | `POST /extract-recipe/{url}`  |
| Open recipe    | `GET /get-recipe/{id}`        |

**Stubbed client-side** (no backend endpoint yet — marked `TODO(backend)` in
`http_recipe_repository.dart`): **delete** and **favorite**. Wire them to real
endpoints when they exist.

Auth currently uses `MockAuthRepository`. The real flow (Google SSO via Supabase
→ exchange at `/login`) drops in behind `AuthRepository` without touching the UI.

## Fonts

Geist + Geist Mono are **bundled** under `fonts/` (SIL OFL — see `fonts/OFL.txt`),
not fetched at runtime, so typography is deterministic and works offline.

## Known simplifications

- Method-step side-notes render in a single color (the handoff greys durations
  inside steps; notes' bold lead-ins are preserved).
- Ingredient checkoff is in-memory per cook session (resets on open), per spec.
- Recipe images are intentionally not rendered (v1 scope).
