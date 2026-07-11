# Handoff: Flavorful — iOS app (Flutter)

> Build an iOS-first recipe management app called **Flavorful**, in Flutter. A web version will follow later; this hand-off covers iOS only, but the same design tokens carry over.

---

## 1. Overview

**Flavorful** is a recipe-keeper. The user signs in with Google, pastes a URL from any food blog, and the app calls a backend that scrapes the page and stores the recipe (title, source, ingredients with notes like "finely chopped", method, scraped notes from the page, hero image URL). The user can then browse their saved recipes, open one, scale servings, and check off ingredients while cooking. There is no editing, no sharing, no collections, no search (yet). Images are **not yet supported in v1** — recipe cards and the detail page are text-only.

**Scope of v1**:

- Sign in (Google)
- Library (list of saved recipes)
- Add recipe (paste a URL, live "saving" state, recipe appears in the list)
- Recipe detail (title, source, time, servings scaler, ingredients with checkoff, method, scraped notes, prominent link to the original page)
- Delete a recipe (from detail page)
- Favorite/save a recipe (star)

**Out of scope for v1**: editing recipes, sharing, collections/tags, search, shopping list, image storage.

---

## 2. About the design files

The files in this bundle are **design references created in HTML** — prototypes showing intended look and behavior, **not production code to copy directly**. They live on a pannable canvas inside `Flavorful.dc.html`. There are two parallel columns:

- **Left column** — the web app (4 frames). For reference only; ignore for this Flutter handoff.
- **Right column** — the iOS mockups (4 frames). **These are what you're building.**

Your task is to **recreate the iOS mockups in Flutter**, using Flutter's native widgets (or Cupertino widgets for the iOS feel) and good Flutter patterns. The HTML is the source of truth for visual design — colors, spacing, type sizes, layout. It is not a structural guide.

---

## 3. Fidelity

**High-fidelity.** Final colors, typography, spacing, and interactions are decided. Build pixel-close in Flutter — exact hex values, the same type sizes, the same padding, the same card shadows. The HTML file uses CSS `px` units; treat 1 px ≈ 1 Flutter logical pixel (dp).

---

## 4. Recommended Flutter stack

Choose what fits the team, but here is what this design assumes:

- **Flutter 3.x**, Dart 3.x
- **Cupertino widgets** for navigation chrome (back button, status bar), **Material** for everything else (it's easier to style freely). Or pure custom widgets; the design isn't standard iOS HIG anyway.
- **State management**: Riverpod or `flutter_bloc`. Recipes are server-owned; client caches.
- **Networking**: `dio` or `http` + `freezed`/`json_serializable` for models.
- **Auth**: `google_sign_in` + `firebase_auth` (or your own backend's OAuth flow).
- **Persistence (cache)**: `drift`, `isar`, or `shared_preferences` for tiny things. Recipes themselves live on the backend.
- **Fonts**: `google_fonts` package — load **Geist** (sans) and **Geist Mono** (mono). Geist is on Google Fonts.
- **SVG icons**: `flutter_svg`. The custom icons in the design (link/chain, paperclip, star, external-link arrow) can be SVG or `Icon` widgets from a Cupertino/Material pack. Specific suggestions below.

---

## 5. Design tokens

Define these once at the top of the project (`lib/theme/tokens.dart` or equivalent) and reference everywhere.

### Colors

| Token | Hex | Used for |
|---|---|---|
| `bgPage` | `#FAFAF8` | App background — every screen below the status bar |
| `bgBeige` | `#F5EDD8` | Recipe cards in the library, the sign-in bottom sheet |
| `bgBeigeBorder` | `#E5DBB8` | Border on the recipe cards |
| `bgBeigeShadow` (rgba) | `rgba(80, 50, 20, 0.12)` and `rgba(80, 50, 20, 0.05)` | Warm shadow under cards |
| `bgNotes` | `#F4F1EA` | "Notes from the page" section background on recipe detail |
| `surface` | `#FFFFFF` | URL paste field, ingredient checkbox bg (unchecked) |
| `brandGreen` | `#2D6A4F` | Sign-in hero panel, primary "Save recipe" button, checked ingredient checkbox, section underlines (Ingredients / Method / Notes), `+` stepper |
| `accentOrange` | `#D4663A` | Brand dot in the wordmark, "source.com" eyebrow text, method step numbers, `→` notes arrows, ★ favorited indicator, "Original page" CTA on detail screen, terracotta focus ring on active URL input, "Saving recipe" pill |
| `accentOrangeDark` | `#9F4A26` | Avatar gradient end stop (`linear-gradient(135deg, #D4663A, #9F4A26)`) |
| `textPrimary` | `#2A2520` | Body text, titles, ingredient text |
| `textSecondary` | `#6B6B6B` | Descriptions, "stirring occasionally" subtle notes inside method steps, sub-copy |
| `textTertiary` | `#A0A0A0` | Eyebrow labels, mono captions, `· 45 min` meta |
| `textInputPlaceholder` | `#A8A8A8` | URL field placeholder text |
| `divider` | `#E8E6E1` | Hairline borders, top-bar bottom border |
| `dividerSoft` | `#EFEDE6` / `#F0EEE8` | Ingredient-row dividers, faint inner borders |
| `inputBorder` | `#E2DFD7` | URL paste input border (resting state) |
| `checkboxBorder` | `#C8C5BD` | Unchecked ingredient checkbox border |
| `googleBtnShadow` (rgba) | `rgba(45, 106, 79, 0.35)` | Drop shadow under the green Continue-with-Google button |

White text on green is `#FAFAF8` (off-white), not `#FFFFFF`, for warmth.

### Typography

Two families, both from **Google Fonts**:

- **Geist** — UI sans. Weights used: 400, 500, 600, 700, 800.
- **Geist Mono** — for source URLs, step numbers, meta data, small uppercase labels.

| Role | Family | Size | Weight | Line-height | Letter-spacing |
|---|---|---|---|---|---|
| Hero ("Every recipe worth saving.") | Geist | 46 | 700 | 0.98 | -0.035em |
| Sign-in title ("What's cooking?") | Geist | 32 | 700 | 1.0 | -0.025em |
| Recipe page title ("Best Lentil Soup") | Geist | 38 | 700 | 1.0 | -0.03em |
| Page title ("42 recipes") | Geist | 32 | 700 | (default) | -0.025em |
| Section header ("Ingredients", "Method", "Notes") | Geist | 18 | 700 | (default) | -0.015em |
| Card title ("Paneer Butter Masala") | Geist | 17 | 600 | 1.25 | -0.01em |
| Method step body | Geist | 15 | 400 | 1.55 | (default) |
| Body / description | Geist | 14 | 400 | 1.5 | (default) |
| Ingredient line | Geist | 14 | 400 (with `font-weight:600` for quantity span) | 1.4 | (default) |
| Card description | Geist | 13 | 400 | 1.45 | -0.005em |
| Notes item text | Geist | 13 | 400 | 1.55 | (default) |
| Stat value ("55 min") | Geist | 18 | 600 | (default) | (default) |
| Stat label ("TIME") | Geist | 10 | 500 | (default) | 0.1em uppercase |
| Source eyebrow ("indianhealthyrecipes.com") | Geist **Mono** | 10 | 500 | (default) | 0.08em uppercase |
| Step number ("01") | Geist Mono | 13 | 600 | (default) | (default) |
| `· 45 min` meta | Geist Mono | 11 | 400 | (default) | (default) |
| Notes arrow "→" | Geist Mono | 12 | 400 | (default) | (default) |
| URL placeholder | Geist | 14 | 400 | (default) | (default) |
| Pasted URL | Geist Mono | 11 | 400 (single-line ellipsis) | (default) | (default) |

In Flutter:
```dart
TextStyle(
  fontFamily: 'Geist',
  fontSize: 38,
  fontWeight: FontWeight.w700,
  height: 1.0,
  letterSpacing: -0.03 * 38, // letter-spacing in CSS is em; in Flutter it's logical px
)
```

### Spacing

The design uses fairly conventional values, mostly multiples of 4:

`4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 40, 56, 60`

Screen edge padding on phone: **20 px** horizontally for content, **16 px** on the top-bar row.

### Radii

| Element | Radius |
|---|---|
| Recipe cards | 10 px |
| URL input field | 10 px |
| Buttons (Google, Save recipe, Original-page CTA) | 8 px |
| Stepper buttons (`+` / `−`) | 4 px |
| Checkbox (ingredient) | 4 px |
| Brand square in wordmark | 2 px |
| Sign-in bottom sheet (top corners) | 24 px |
| Notes-from-page section | 0 (full-width band) |

### Shadows

- **Card shadow** (light beige cards on cream bg):
  `0 8px 20px -6px rgba(80, 50, 20, 0.12), 0 2px 4px rgba(80, 50, 20, 0.05)`
- **URL input shadow** (resting): `0 2px 8px -2px rgba(0, 0, 0, 0.06)`
- **URL input shadow** (active/focused, orange ring): `0 0 0 4px rgba(212, 102, 58, 0.10)` plus the same focus border `1.5 px solid #D4663A`
- **Google sign-in button**: `0 8px 20px -6px rgba(45, 106, 79, 0.35)`
- **Original-page CTA on recipe detail**: `0 6px 14px -4px rgba(212, 102, 58, 0.35)`

---

## 6. Screens

There are **4 screens** in this v1 (matching the 4 iOS mockup frames in the canvas). Each section below: name, purpose, exact layout, interactions.

### Screen 1 — Sign in

**Purpose**: First-run / signed-out state. Single button to authenticate with Google.

**Layout**:
- Full-screen sage green (`#2D6A4F`) hero panel taking roughly the top 60-65% of the screen. Status bar text is **white** here (`SystemUiOverlayStyle.light`).
- The "flavorful" wordmark sits top-left at `padding: 80, 28, 0` (top padding accounts for the status bar / dynamic island).
- Below the wordmark, with `margin-top: 60`, the hero copy:
  - "Every recipe" in 46/0.98, weight 700, color `#FAFAF8`
  - "worth saving." on the next line, same size/weight, color `#D4663A` (orange accent)
- Below the title, a short paragraph at `font-size: 16`, `color: rgba(250, 250, 248, 0.7)`, `line-height: 1.5`, `margin-top: 20`: *"Paste a link from any food blog. We pull the recipe, ditch the life story."*
- A beige bottom sheet (`#F5EDD8`) is anchored at the bottom (`margin-top: auto` in flex), with `border-radius: 24px 24px 0 0`, padding `36, 28, 60, 28` (top, R, bottom, L).
  - "What's cooking?" — 32/1.0, weight 700, color `#2A2520`.
  - `margin-top: 28`: a full-width sage-green button, height 58, radius 8, color `#FAFAF8`, with the Google "G" multi-color SVG icon at the left and the label "Continue with Google" centered. Box-shadow as listed in tokens.

**Wordmark anatomy**: a 10×10 px square in `#D4663A` with `border-radius: 2`, then 8 px gap, then the text "flavorful" in Geist 22, weight 800, `letter-spacing: -0.03em`, `color: #FAFAF8`.

**Interactions**:
- Tap "Continue with Google" → trigger `google_sign_in` flow. On success, push the Library screen and clear the navigation stack.
- The hero panel itself is decorative — no taps.

### Screen 2 — Library (idle)

**Purpose**: Browse saved recipes. Paste a URL to add a new one.

**Layout** (status bar at top, white system overlay style):
- **Top bar** — full width, padding `14, 20`. Wordmark on the left (size 18 instead of 22 on this screen), "M" avatar circle on the right.
  - Avatar: 32×32 circle, `linear-gradient(135deg, #D4663A, #9F4A26)`, white "M" centered, font-size 12, weight 600.
- **Title block** — padding `24, 20, 0`:
  - Eyebrow "Your library" — Geist 11, weight 500, color `#A0A0A0`, `letter-spacing: 0.12em`, uppercase.
  - "42 recipes" — Geist 32, weight 700, `letter-spacing: -0.025em`, color `#2A2520`, `margin-top: 4`.
- **URL paste field** — padding `20, 20, 0`:
  - Container: white `#FFFFFF`, border `1.5 px solid #E2DFD7`, radius 10, shadow `0 2px 8px -2px rgba(0, 0, 0, 0.06)`.
  - Row layout. Left: 14 px horizontal padding, chain-link icon (`flutter_svg` or `Icons.link` rotated; the design uses an SVG 18×18 with `stroke-width: 2`, color `#D4663A`).
  - Right of the icon: a text input area, 56 px tall, font 14, color `#2A2520` when typed, placeholder color `#A8A8A8`, placeholder text exactly: **"Paste a recipe URL"** — no descriptive suffix.
  - No save button visible at rest (the Save action triggers on Enter / paste — see Screen 3).
- **Card list** — padding `20, 20, 90` (the 90 bottom accounts for the home indicator and breathing room). Layout is a vertical column with `gap: 14`. Each card is a recipe card (see "Card anatomy" below).

**Card anatomy**:
- Container: `#F5EDD8` bg, 1 px solid `#E5DBB8` border, radius 10, padding `18, 18, 16, 18`, card shadow.
- If favorited: a `★` in `#D4663A` at top-right, font-size 14, position absolute `top: 14, right: 16`.
- Source eyebrow (Geist Mono 10, weight 500, color `#D4663A`, `letter-spacing: 0.08em`, uppercase) — the source URL's hostname.
- `margin-top: 8`: Title (Geist 17, weight 600, color `#2A2520`, line-height 1.25, letter-spacing -0.01em). Add `padding-right: 24` if the card is favorited so the title doesn't collide with the star.
- `margin-top: 6`: Description (Geist 13, color `#6B6B6B`, line-height 1.45).
- `margin-top: 12`: Mono meta — "45 min" (Geist Mono 11, color `#A0A0A0`).

**Sample data shown in the mock** (use whatever you have — these are placeholders):
1. ★ Paneer Butter Masala · indianhealthyrecipes.com · 45 min — *"Creamy tomato-cashew gravy, restaurant-style."*
2. Best Lentil Soup · cookieandkate.com · 55 min — *"Curry powder, lemon, and a creamy blended finish."*
3. Brown Butter Gnocchi · smittenkitchen.com · 30 min — *"Nutty brown butter, crispy sage, parmesan."*
4. Charred Cabbage Wedges · bonappetit.com · 35 min — *"Smoky wedges with anchovy-caper butter."*

**Interactions**:
- Tap a card → push the Recipe Detail screen with the recipe's id.
- Tap the URL field → focus it, keyboard slides up.
- Paste / type a URL and press Enter (or the iOS keyboard's "Go") → switch to Screen 3 (saving state). The field's border turns orange `#D4663A`, an orange ring `0 0 0 4px rgba(212, 102, 58, 0.10)` appears, the placeholder is replaced by the pasted URL (Geist Mono 11, color `#2A2520`), and a small saving row appears below.
- Tap avatar → (out of scope for v1; could open a settings sheet later).

### Screen 3 — Library (saving a new recipe)

**Purpose**: Same as Library, but in the middle of a scrape after a URL was pasted.

**Layout deltas from Screen 2**:
- Above the "42 recipes" title, replace the **eyebrow** with a small saving indicator: a 7×7 orange dot with a `box-shadow: 0 0 0 4px rgba(212, 102, 58, 0.15)` halo (pulsing softly if you want), 8 px gap, then **"Saving recipe"** in Geist 11, weight 600, color `#D4663A`, `letter-spacing: 0.12em`, uppercase.
- The URL field is now in the focused/active state:
  - Border `1.5 px solid #D4663A`, ring `0 0 0 4px rgba(212, 102, 58, 0.10)`.
  - The text area shows the pasted URL truncated with ellipsis. Example: `cookieandkate.com/best-lentil…`. Font: Geist Mono 11, color `#2A2520`.
  - A second row beneath the URL row, full-width, `border-top: 1 px solid #F0EEE8`, background `#FAFAF8`, padding `12, 16`. Contents:
    - 16×16 spinner — a circle with `border: 2 px solid #2D6A4F`, `border-right-color: transparent`, rotating.
    - 12 px gap, then "Fetching recipe…" in Geist 13, weight 500, color `#2A2520`.
- The existing cards continue beneath, unchanged.

**Interactions**:
- The spinner runs while the backend is scraping (POST to your API — see Section 8).
- On success: dismiss the saving state, prepend the new recipe card to the list with a subtle slide-in animation (200 ms, `Curves.easeOut`).
- On failure: replace the spinner row with an error chip, color `#D4663A` text on a light background, with a "Try again" button. Copy: "Couldn't read that page. Try a different URL." Keep the URL in the field.
- Tap anywhere outside the field while saving → still keeps saving in the background; field remains in the focused look until the API resolves.

### Screen 4 — Recipe detail

**Purpose**: Read the recipe. Cook from it. Get back to the original page.

This screen is the longest — content scrolls. The taller frame in the mockup (1620 px) shows everything stacked; the visible viewport on a real iPhone is the top portion, the rest scrolls.

**Layout** (top to bottom):

1. **Top bar** — padding `14, 16`, with a `border-bottom: 1 px solid #EFEDE6`.
   - Left: a chevron `<` icon and "Library" text in green `#2D6A4F`, Geist 15, weight 500. Tappable — pops the route.
   - Right: a row of two icons, gap 14.
     - ★ filled with `#D4663A`, stroke `#D4663A`, 20×20. Tap toggles favorite. (Use `Icons.star` for now or a custom SVG.)
     - 🗑 trash icon in `#6B6B6B`, 20×20, stroke-width 2. Tap → confirmation dialog → DELETE the recipe and pop to Library.
2. **Prominent Original-page CTA** — padding `16, 20, 0`. A full-width orange button:
   - Height 46, background `#D4663A`, radius 8, color `#FFFFFF`, font-size 14, weight 600, shadow `0 6px 14px -4px rgba(212, 102, 58, 0.35)`.
   - Icon (external-link, 14×14, `stroke: currentColor`, `stroke-width: 2.2`) + 8 px gap + text "View on cookieandkate.com" (substitute the actual source hostname). Tap → open the URL in the system browser (`url_launcher` package).
3. **Title block** — padding `24, 20, 0`:
   - Source eyebrow: Geist Mono 10, weight 500, color `#D4663A`, uppercase, `letter-spacing: 0.08em` — the source hostname.
   - `margin-top: 10`: title in Geist 38, weight 700, line-height 1.0, `letter-spacing: -0.03em`, color `#2A2520`.
   - `margin-top: 12`: description in Geist 14, color `#6B6B6B`, line-height 1.5. (Scraped from the page; may be blank — collapse the line if so.)
4. **Stats row** — padding `20, 20, 0`. A horizontal flex row, `gap: 24`, items aligned to the bottom. Three columns:
   - **Time** — label "TIME" (Geist 10, color `#A0A0A0`, uppercase, `letter-spacing: 0.1em`), value `55 min` (Geist 18, weight 600, color `#2A2520`).
   - **Serves** — label "SERVES", value with a stepper: `[−] 4 [+]`. `−` is a white 22×22 square, `border: 1 px solid #E8E6E1`, font-size 13, color `#6B6B6B`. `+` is a green 22×22 square, color `#FAFAF8`. The "4" is Geist 18, weight 600, color `#2A2520`, `min-width: 16` centered.
   - **Difficulty** — label "DIFFICULTY", value "Easy" (same style as time value).
5. **Ingredients section** — padding `32, 20, 0`:
   - Header row, baseline-aligned, `padding-bottom: 10`, `border-bottom: 2 px solid #2D6A4F`.
     - "Ingredients" — Geist 18, weight 700, color `#2D6A4F`, `letter-spacing: -0.015em`.
     - "14 · serves 4" — Geist Mono 11, color `#A0A0A0`.
   - List items (no inner card, just rows with a hairline divider `1 px solid #F0EEE8` between them):
     - Layout: a row, `gap: 12`, `padding: 10, 0`.
     - Left: a checkbox — 18×18, `border-radius: 4`. Unchecked: white inside, `1.5 px solid #C8C5BD`. Checked: `#2D6A4F` filled, with a `#D4663A` ✓ glyph centered (font-size 10, weight 700). Tapping toggles.
     - Right: the ingredient text. Quantity in `font-weight: 600`, then the ingredient name, then optionally an em-dash and a side-note in `color: #6B6B6B`, e.g. `**1** onion — finely chopped`.
     - Checked rows get `opacity: 0.4` on the right-hand text and `text-decoration: line-through`.
   - After 7 ingredients, a small italic placeholder in the mockup: `+ 7 more ingredients` (`font-size: 12`, color `#A0A0A0`, italic, `padding: 10 0`) — in the real app, just render all 14.
6. **Method section** — padding `24, 20, 0`:
   - Header same style as Ingredients. "Method" + "8 steps".
   - `margin-top: 18`: a vertical column of step items, `gap: 18`. Each step:
     - Row, `gap: 14`.
     - Left: step number "01", "02"… in Geist Mono 13, weight 600, color `#D4663A`, min-width 26, padding-top 2.
     - Right: step body — Geist 15, line-height 1.55, color `#2A2520`. Subtle / side-note text (durations, alternates) wrapped in a `<span style="color:#6B6B6B">` equivalent.
7. **Notes section** ("Notes from the page" — scraped content from the blog) — padding `24, 20, 90` (the bottom 90 is for the home indicator).
   - Header: "Notes" — same style as Ingredients/Method.
   - `margin-top: 16`: vertical list, `gap: 14`. Each note:
     - Row, `gap: 12`.
     - Left: an `→` glyph in Geist Mono 12, color `#D4663A`, min-width 16, padding-top 3.
     - Right: note body in Geist 13, line-height 1.55, color `#2A2520`. Common bold lead-in like `**Make it vegan.** Already vegan if your broth is vegetable-based.` Use a `RichText` / `Text.rich` with two `TextSpan`s for the bold lead-in.

**Servings interaction**:
- Tapping `−` decrements (min 1). Tapping `+` increments (no upper limit, but cap at say 24 to avoid silliness).
- All **ingredient quantities scale proportionally** to the new serving count vs the original. Use rational fractions where possible (`¼`, `½`, `¾`, `⅓`, `⅔`, `1¼`, …) — the package `fraction` or a tiny helper can convert decimals to mixed fractions for display.

**Checkoff state**: lives in memory only (per-cook session). Reset every time the user opens the screen — do not persist to the backend. (If you want, persist to local storage keyed by recipe id.)

**Original-page link**: opens in the system browser via `url_launcher`'s `launchUrl` with `LaunchMode.externalApplication`.

---

## 7. Components

Reusable widgets you'll want:

| Widget | Notes |
|---|---|
| `RecipeCard` | Used in Library. Props: source, title, description, time, isFavorited, onTap. |
| `UrlPasteField` | The full-width input. Props: value, isLoading, errorText, onSubmitted. |
| `Stepper` | The `[−] 4 [+]` widget. Props: value, onChanged, min, max. |
| `IngredientCheckbox` | The 18×18 box with the orange-on-green check. Props: checked, onChanged. |
| `MethodStep` | A numbered step row. Props: number, body (RichText). |
| `SectionHeader` | "Ingredients · 14 · serves 4". Props: title, meta. |
| `Wordmark` | The flavorful brand block. Props: size (sm/md/lg), onDark (bool). |
| `OriginalPageCta` | Full-width orange button for the detail screen. Props: hostname, onTap. |
| `SourceEyebrow` | Mono uppercase orange label. Props: hostname. |

---

## 8. Backend API (assumed)

The user owns the backend, but the iOS app expects these endpoints. Confirm shape with them.

| Endpoint | Purpose | Response |
|---|---|---|
| `POST /v1/auth/google` body `{idToken}` | Exchange Google ID token for an app session token | `{sessionToken, user}` |
| `GET /v1/recipes` | List user's saved recipes | `{recipes: Recipe[]}` |
| `POST /v1/recipes` body `{url}` | Scrape and save a recipe from a blog URL — **this is the long-running call powering Screen 3** | `{recipe: Recipe}` (or 4xx with error message) |
| `GET /v1/recipes/:id` | Full recipe | `{recipe: Recipe}` |
| `DELETE /v1/recipes/:id` | Delete | `204` |
| `POST /v1/recipes/:id/favorite` | Toggle favorite | `{isFavorited: bool}` |

**Recipe shape** (suggested):
```dart
class Recipe {
  String id;
  String url;            // original source URL
  String hostname;       // "cookieandkate.com"
  String title;
  String description;    // scraped summary, may be empty
  int totalMinutes;      // "55 min" → 55
  int servings;          // default servings the recipe was scraped at
  String? difficulty;    // "Easy" | "Medium" | "Hard" — optional
  List<Ingredient> ingredients;
  List<String> method;    // ordered list of step bodies (plain text or markdown)
  List<NoteFromPage> notesFromPage;
  String? heroImageUrl;   // null in v1 — UI does not render images yet
  bool isFavorited;
  DateTime savedAt;
}
class Ingredient {
  String quantityRaw;  // "¼ cup", "1", "4 cloves"
  double? quantityValue; // 0.25, 1, 4 — for servings scaling
  String? unit;          // "cup", "cloves", null
  String name;           // "olive oil", "onion"
  String? sideNote;      // "finely chopped"
}
class NoteFromPage {
  String? boldLeadIn;    // "Make it vegan."
  String body;           // "Already vegan if your broth is vegetable-based."
}
```

The mock data in the design uses scraped recipes from these real blog URLs — you can use them when testing the live API:
- https://www.indianhealthyrecipes.com/paneer-butter-masala-restaurant-style/
- https://www.indianhealthyrecipes.com/masala-pasta/
- https://cookieandkate.com/best-lentil-soup-recipe/

---

## 9. Navigation

Stack-based (`Navigator 2.0` or your favorite router):

```
Sign in   ─┬─ (Google success) ─►  Library
           │
Library  ──┬─ (paste URL → success) ─► Library refresh (no nav)
           ├─ (tap card)              ─► Recipe Detail
           └─ (tap avatar)            ─► (out of scope v1)

Recipe Detail ─┬─ (back arrow)         ─► pop to Library
                ├─ (delete confirmed)   ─► pop to Library, refresh
                └─ (View on …)         ─► external browser (no nav change)
```

No tab bar. The home indicator at the bottom of each screen is the only thing in the bottom 90 px.

---

## 10. Status bar and home indicator

- **Sign in screen**: green hero → `SystemUiOverlayStyle.light` (white time / battery).
- **All other screens**: cream bg → `SystemUiOverlayStyle.dark`.
- The home indicator: the IOSDevice mockup shows a 139×5 pill, `rgba(0, 0, 0, 0.25)`, 8 px from the bottom. The Flutter system renders this automatically — no work needed, but reserve `90 px` at the bottom of scrollable content to avoid collisions.

---

## 11. Assets

- **No bundled images** in v1. Recipe images are intentionally not stored or rendered (user's call).
- **Fonts**: Geist + Geist Mono via `google_fonts`.
- **Icons** in the design:
  - Chain-link (URL field): custom 2-path SVG, 18×18, `stroke: currentColor`, `stroke-width: 2`, `stroke-linecap: round`, `stroke-linejoin: round`. Or substitute `Icons.link` rotated 135°.
  - External-link (Original page CTA, top-bar): 3-element SVG (square + arrow + diagonal line). Or `Icons.open_in_new`.
  - Star (favorite): filled 5-pointer SVG. Or `Icons.star`.
  - Trash (delete): 4-path SVG. Or `Icons.delete_outline`.
  - Chevron `<` (back): or `Icons.arrow_back_ios` from Cupertino.
  - Google "G": multi-colored SVG (already inlined in the mock).
- Use `flutter_svg` if you keep the SVGs literal; otherwise the Material/Cupertino icon equivalents are fine.

---

## 12. Files in this bundle

| File | Purpose |
|---|---|
| `README.md` | This document. |
| `Flavorful.dc.html` | The HTML design file. Open it in a browser to inspect the iOS mocks on the right column. Hover/right-click → "Inspect" to read exact CSS values. |
| `ios-frame.jsx` | The iOS device frame component used in the mocks. Reference only — shows the dynamic island position, home indicator, and how the status bar is composed. **Do not port this** — Flutter renders all of that natively. |

To open the HTML: just double-click it. Pan around the canvas to see all 4 mobile frames stacked on the right.

---

## 13. Notes & gotchas

- **Servings scaling**: do the math on the `quantityValue` field, then convert decimals back to mixed fractions for display. `0.5 cup` should show as `½ cup`. `1.25 cup` as `1¼ cup`. Drop the unit when the value is exactly 1 of a count noun (e.g. `1 onion`, not `1 onion(s)`).
- **Side notes** on ingredients ("finely chopped", "peeled & diced") **must** stay attached to the ingredient — the scraper should split them out from the main quantity+name. If the backend gives them joined, the UI can render the whole string with the side-note implicit, but you lose the gray color distinction.
- **Empty states**: Library with 0 saved recipes should show a friendly empty state above the URL field. Suggested copy: *"Paste a link to your first recipe."* — same Geist 14, color `#6B6B6B`.
- **Pull-to-refresh** on the Library is a nice-to-have for v1; the existing card list scrolls so wire it up to refetch `GET /v1/recipes`.
- **Dark mode**: not designed yet. Force light mode for v1: set `themeMode: ThemeMode.light` and `darkTheme: null` in `MaterialApp`.

---

## 14. Next steps (after v1 ships)

For when you come back for v2 — these are designed but **not** scoped for this build:
- Search, collections/tags, shopping list
- Edit a recipe
- Sharing
- Image storage and a photo-forward grid for the Library
- Android-specific Material polish
- Web app (the left column of the design canvas previews where this is heading)

---

*Generated 2026. Source HTML: `Flavorful.dc.html` (right-column iOS frames). Questions on the design: refer to the HTML; everything is inline-styled and readable.*
