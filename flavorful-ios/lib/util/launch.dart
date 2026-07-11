import 'package:url_launcher/url_launcher.dart';

/// Open [url] in the browser. Tries the external browser first, then falls back
/// to an in-app Safari view, so a policy/support link always opens even if the
/// external launch is refused. Silently no-ops if the URL is unusable.
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  for (final mode in const [
    LaunchMode.externalApplication,
    LaunchMode.inAppBrowserView,
    LaunchMode.platformDefault,
  ]) {
    try {
      if (await launchUrl(uri, mode: mode)) return;
    } catch (_) {
      // Try the next mode.
    }
  }
}
