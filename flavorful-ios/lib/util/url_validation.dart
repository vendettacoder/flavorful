/// Lightweight client-side URL checks. The backend is the real security
/// boundary (SSRF, scheme/host enforcement); this only gives instant UX
/// feedback and avoids obviously-junk network requests.
library;

const int kMaxUrlLength = 2048;

/// Prepends `https://` when the input has no http(s) scheme.
String normalizeUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return s;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) return s;
  return 'https://$s';
}

/// True if [raw] (after normalization) looks like a fetchable public recipe URL:
/// http/https scheme, a host with a dot, and within the length cap.
bool isLikelyRecipeUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s.length > kMaxUrlLength) return false;
  final uri = Uri.tryParse(normalizeUrl(s));
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  return uri.host.contains('.');
}
