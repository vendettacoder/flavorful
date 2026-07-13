import '../util/fractions.dart';

/// Domain models for a saved recipe. Plain immutable value types with tolerant
/// JSON mapping — no code generation, to keep the build simple. The JSON keys
/// accept a few aliases so the same models work against the mock repository and
/// the real backend without edits.

class Ingredient {
  const Ingredient({
    required this.quantityRaw,
    required this.name,
    this.quantityValue,
    this.unit,
    this.sideNote,
  });

  /// Original quantity text, e.g. "¼ cup", "1", "4 cloves".
  final String quantityRaw;

  /// Numeric quantity for servings scaling, e.g. 0.25, 1, 4. Null if unscalable.
  final double? quantityValue;

  /// Unit of measure, e.g. "cup", "cloves". Null for bare count nouns.
  final String? unit;

  /// Ingredient name, e.g. "olive oil", "onion".
  final String name;

  /// Preparation note rendered in gray, e.g. "finely chopped".
  final String? sideNote;

  /// The bold quantity label scaled by [factor] (newServings / baseServings).
  /// Falls back to [quantityRaw] when the quantity isn't numeric.
  String scaledQuantityLabel(double factor) {
    final value = quantityValue;
    if (value == null) return quantityRaw;
    final q = formatQuantity(value * factor);
    if (unit == null || unit!.isEmpty) return q;
    return '$q $unit';
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final raw = (json['quantity_raw'] ?? json['quantityRaw'] ?? '') as String;
    final value = json['quantity_value'] ?? json['quantityValue'];
    return Ingredient(
      quantityRaw: raw,
      quantityValue: value == null ? null : (value as num).toDouble(),
      unit: json['unit'] as String?,
      name: (json['name'] ?? '') as String,
      sideNote: (json['side_note'] ?? json['sideNote']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'quantity_raw': quantityRaw,
        'quantity_value': quantityValue,
        'unit': unit,
        'name': name,
        'side_note': sideNote,
      };

  /// Parses a freeform backend ingredient string of the shape
  /// `<quantity> <name> (<note>)`. The whole quantity-plus-name portion becomes
  /// [name] (rendered as one run, since the backend doesn't separate quantity),
  /// and any trailing parenthetical becomes the gray [sideNote]. Not scalable.
  factory Ingredient.fromBackendString(String raw) {
    var text = raw.trim();
    String? note;
    final match = RegExp(r'\(([^)]*)\)\s*$').firstMatch(text);
    if (match != null) {
      note = match.group(1)?.trim();
      text = text.substring(0, match.start).trim();
      if (note != null && note.isEmpty) note = null;
    }
    return Ingredient(quantityRaw: '', name: text, sideNote: note);
  }

  /// Parses a structured backend ingredient object
  /// `{ quantity:number|null, unit, name, note }`. A numeric [quantityValue]
  /// makes the ingredient scalable.
  factory Ingredient.fromBackendObject(Map<String, dynamic> json) {
    final q = json['quantity'];
    final unit = (json['unit'] as String?)?.trim();
    final note = (json['note'] as String?)?.trim();
    return Ingredient(
      quantityRaw: '',
      quantityValue: q is num ? q.toDouble() : null,
      unit: (unit == null || unit.isEmpty) ? null : unit,
      name: (json['name'] ?? '').toString().trim(),
      sideNote: (note == null || note.isEmpty) ? null : note,
    );
  }
}

class NoteFromPage {
  const NoteFromPage({required this.body, this.boldLeadIn});

  /// Bold lead-in such as "Make it vegan.". Optional.
  final String? boldLeadIn;

  /// Note body text.
  final String body;

  factory NoteFromPage.fromJson(Map<String, dynamic> json) => NoteFromPage(
        boldLeadIn: (json['bold_lead_in'] ?? json['boldLeadIn']) as String?,
        body: (json['body'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'bold_lead_in': boldLeadIn,
        'body': body,
      };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.url,
    required this.hostname,
    required this.title,
    required this.description,
    required this.totalMinutes,
    required this.servings,
    required this.ingredients,
    required this.method,
    required this.notesFromPage,
    required this.isFavorited,
    required this.savedAt,
    this.servingsKnown = true,
    this.difficulty,
    this.heroImageUrl,
    this.nutrition = const {},
  });

  final String id;
  final String url; // original source URL
  final String hostname; // "cookieandkate.com"
  final String title;
  final String description; // scraped summary, may be empty
  final int totalMinutes; // "55 min" → 55
  final int servings; // servings the recipe was scraped at (1 when unknown)
  /// Whether [servings] came from the page. False when the source had no
  /// servings count and it fell back to 1 — the UI hides the stepper then.
  final bool servingsKnown;
  final String? difficulty; // "Easy" | "Medium" | "Hard"
  final List<Ingredient> ingredients;
  final List<String> method; // ordered step bodies
  final List<NoteFromPage> notesFromPage;
  final String? heroImageUrl; // null in v1 — not rendered
  final bool isFavorited;
  final DateTime savedAt;

  /// Nutrition macros from the page, e.g. {"Calories": "320 kcal"}. May be empty.
  final Map<String, String> nutrition;

  /// Calorie value pulled from [nutrition] (any key like "calories"/"energy"/
  /// "kcal"), or null if absent.
  String? get calories {
    for (final entry in nutrition.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('calorie') || key.contains('energy') || key == 'kcal') {
        final value = entry.value.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  Recipe copyWith({bool? isFavorited, int? servings}) => Recipe(
        id: id,
        url: url,
        hostname: hostname,
        title: title,
        description: description,
        totalMinutes: totalMinutes,
        servings: servings ?? this.servings,
        servingsKnown: servingsKnown,
        difficulty: difficulty,
        ingredients: ingredients,
        method: method,
        notesFromPage: notesFromPage,
        heroImageUrl: heroImageUrl,
        isFavorited: isFavorited ?? this.isFavorited,
        savedAt: savedAt,
        nutrition: nutrition,
      );

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ?? json['source_url'] ?? '') as String;
    return Recipe(
      id: (json['id'] ?? '').toString(),
      url: url,
      hostname: (json['hostname'] as String?) ?? hostnameFromUrl(url),
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      totalMinutes:
          ((json['total_minutes'] ?? json['totalMinutes'] ?? 0) as num).toInt(),
      servings: ((json['servings'] ?? 1) as num).toInt(),
      servingsKnown: (json['servings_known'] as bool?) ??
          servingsKnownFrom(json['servings']),
      difficulty: json['difficulty'] as String?,
      ingredients: ((json['ingredients'] ?? []) as List)
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      method: ((json['method'] ?? []) as List).map((e) => e.toString()).toList(),
      notesFromPage:
          ((json['notes_from_page'] ?? json['notesFromPage'] ?? []) as List)
              .map((e) => NoteFromPage.fromJson(e as Map<String, dynamic>))
              .toList(),
      heroImageUrl: (json['hero_image_url'] ?? json['heroImageUrl']) as String?,
      isFavorited: (json['is_favorited'] ?? json['isFavorited'] ?? false) as bool,
      savedAt: DateTime.tryParse(
            (json['saved_at'] ?? json['savedAt'] ?? '') as String,
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// Maps a `recipe_db` row from the FastAPI backend. The recipe content lives
  /// in `recipe_metadata` (a flat object produced by the LLM extractor):
  /// `{ recipe_name, servings, ingredients[], method[], notes[], ... }`.
  factory Recipe.fromBackendRow(Map<String, dynamic> row) {
    final meta = (row['recipe_metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final url = (row['public_url'] ?? '') as String;
    final methodRaw =
        (meta['method'] ?? meta['instructions'] ?? meta['steps'] ?? const [])
            as List;
    return Recipe(
      id: (row['recipe_id'] ?? '').toString(),
      url: url,
      hostname: hostnameFromUrl(url),
      title: (meta['recipe_name'] as String?)?.trim().isNotEmpty == true
          ? meta['recipe_name'] as String
          : 'Untitled recipe',
      description: (meta['description'] as String?)?.trim() ?? '',
      totalMinutes: 0, // backend has no time field
      servings: parseServings(meta['servings']),
      servingsKnown: servingsKnownFrom(meta['servings']),
      difficulty: null,
      ingredients: ((meta['ingredients'] as List?) ?? const [])
          .map((e) => e is Map
              ? Ingredient.fromBackendObject(e.cast<String, dynamic>())
              : Ingredient.fromBackendString(e.toString()))
          .toList(),
      method: methodRaw.map((e) => e.toString()).toList(),
      notesFromPage: ((meta['notes'] as List?) ?? const [])
          .map((e) => NoteFromPage(body: e.toString()))
          .toList(),
      heroImageUrl: null,
      isFavorited: (row['is_favorited'] as bool?) ?? false,
      savedAt: DateTime.tryParse((row['created_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      nutrition: _nutritionFrom(meta['nutrition_information']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'hostname': hostname,
        'title': title,
        'description': description,
        'total_minutes': totalMinutes,
        'servings': servings,
        'servings_known': servingsKnown,
        'difficulty': difficulty,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'method': method,
        'notes_from_page': notesFromPage.map((e) => e.toJson()).toList(),
        'hero_image_url': heroImageUrl,
        'is_favorited': isFavorited,
        'saved_at': savedAt.toIso8601String(),
      };
}

/// Parses a servings value that may be an int or a string like "4" or
/// "4 servings". Defaults to 1.
int parseServings(dynamic value) {
  if (value == null) return 1;
  if (value is num) return value.toInt() < 1 ? 1 : value.toInt();
  final match = RegExp(r'\d+').firstMatch(value.toString());
  if (match == null) return 1;
  final n = int.parse(match.group(0)!);
  return n < 1 ? 1 : n;
}

/// Whether a servings value from the source is a real, usable count (a positive
/// number). False for null, empty, or non-numeric values — those fall back to 1
/// via [parseServings], and the UI hides the servings stepper in that case.
bool servingsKnownFrom(dynamic value) {
  if (value == null) return false;
  if (value is num) return value.toInt() >= 1;
  final match = RegExp(r'\d+').firstMatch(value.toString());
  if (match == null) return false;
  return int.parse(match.group(0)!) >= 1;
}

/// Normalizes the backend `nutrition_information` map (macro → "amount unit"),
/// dropping empty values.
Map<String, String> _nutritionFrom(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    final value = v?.toString().trim() ?? '';
    final key = k.toString().trim();
    if (key.isNotEmpty && value.isNotEmpty) out[key] = value;
  });
  return out;
}

/// Extracts a bare hostname (no scheme, no `www.`, no path) from a URL.
String hostnameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  var host = uri?.host ?? '';
  if (host.isEmpty) {
    // Best-effort parse for inputs missing a scheme, e.g. "cookieandkate.com/x".
    host = url.replaceFirst(RegExp(r'^https?://'), '').split('/').first;
  }
  return host.replaceFirst(RegExp(r'^www\.'), '');
}
