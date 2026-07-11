/// Decimal → mixed-fraction rendering for servings scaling.
///
/// `0.5` → `½`, `1.25` → `1¼`, `0.333…` → `⅓`. Falls back to a trimmed
/// decimal when no clean fraction (denominator ≤ 8) is close enough.
library;

const Map<String, String> _glyphs = {
  '1/2': '½',
  '1/3': '⅓',
  '2/3': '⅔',
  '1/4': '¼',
  '3/4': '¾',
  '1/8': '⅛',
  '3/8': '⅜',
  '5/8': '⅝',
  '7/8': '⅞',
};

/// Allowed denominators, in preference order (halves, then thirds, quarters…).
const List<int> _denominators = [2, 3, 4, 8];

/// How close a value must be to a fraction to snap to it.
const double _tolerance = 0.02;

/// Formats [value] as a mixed fraction string, e.g. `1¼`.
///
/// Returns an empty string for non-positive values.
String formatQuantity(double value) {
  if (value <= 0) return '';

  final whole = value.floor();
  final frac = value - whole;

  // Whole-number (or effectively whole) values.
  if (frac < _tolerance) return '$whole';
  if (frac > 1 - _tolerance) return '${whole + 1}';

  final glyph = _closestFractionGlyph(frac);
  if (glyph == null) {
    // No clean fraction — show a tidy decimal instead.
    final trimmed = _trimDecimal(value);
    return trimmed;
  }

  return whole == 0 ? glyph : '$whole$glyph';
}

String? _closestFractionGlyph(double frac) {
  for (final d in _denominators) {
    for (var n = 1; n < d; n++) {
      if ((frac - n / d).abs() <= _tolerance) {
        final reduced = _reduce(n, d);
        return _glyphs['${reduced.$1}/${reduced.$2}'];
      }
    }
  }
  return null;
}

(int, int) _reduce(int n, int d) {
  final g = _gcd(n, d);
  return (n ~/ g, d ~/ g);
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

String _trimDecimal(double value) {
  final s = value.toStringAsFixed(2);
  // Strip trailing zeros and a dangling decimal point.
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}
