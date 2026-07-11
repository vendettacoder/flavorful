import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// Centralized icon set. Each icon is the literal SVG from the design handoff
/// (`Flavorful.dc.html`), rendered with `flutter_svg`. Monochrome icons use
/// `currentColor` and are tinted via [colorFilter]; the Google "G" and the
/// star keep their baked-in colors.
class AppIcons {
  AppIcons._();

  static Widget _mono(String data, double size, Color color) {
    return SvgPicture.string(
      data,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  /// Chain-link — URL paste field.
  static Widget chainLink({double size = 18, Color color = AppColors.accentOrange}) =>
      _mono(_chainLink, size, color);

  /// Back chevron — detail top bar.
  static Widget chevronBack({double size = 18, Color color = AppColors.brandGreen}) =>
      _mono(_chevron, size, color);

  /// Trash — delete action.
  static Widget trash({double size = 20, Color color = AppColors.textSecondary}) =>
      _mono(_trash, size, color);

  /// External-link — Original-page CTA.
  static Widget externalLink({double size = 14, Color color = AppColors.surface}) =>
      _mono(_externalLink, size, color);

  /// Star — favorite indicator. [filled] = favorited (orange); otherwise a gray
  /// outline.
  static Widget star({double size = 20, bool filled = true}) {
    final fill = filled ? '#D4663A' : 'none';
    final stroke = filled ? '#D4663A' : '#C8C5BD';
    final data =
        '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
        'viewBox="0 0 24 24" fill="$fill" stroke="$stroke" stroke-width="2" '
        'stroke-linejoin="round"><polygon points="12 2 15 9 22 9 17 14 19 22 '
        '12 18 5 22 7 14 2 9 9 9 12 2"/></svg>';
    return SvgPicture.string(data, width: size, height: size);
  }

  /// Arrow-right — the Save-island submit button.
  static Widget arrowRight({double size = 13, Color color = AppColors.onGreen}) =>
      _mono(_arrowRight, size, color);

  /// Magnifying glass — the search pill.
  static Widget search({double size = 15, Color color = AppColors.sageMuted}) =>
      _mono(_search, size, color);

  /// The standard multi-color Google "G".
  static Widget googleG({double size = 18}) =>
      SvgPicture.string(_googleG, width: size, height: size);

  /// The brand tomato mark (from the app-icon handoff), background-less so it
  /// sits beside the wordmark. Height-sized; width scales to its aspect.
  static Widget tomatoMark({double size = 22}) =>
      SvgPicture.string(_tomatoMark, height: size);
}

const _chainLink =
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.72"/>'
    '<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.72-1.72"/>'
    '</svg>';

const _arrowRight =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<line x1="5" y1="12" x2="19" y2="12"/>'
    '<polyline points="12 5 19 12 12 19"/></svg>';

const _search =
    '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<circle cx="11" cy="11" r="8"/>'
    '<line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>';

const _chevron =
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<polyline points="15 18 9 12 15 6"/></svg>';

const _trash =
    '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<polyline points="3 6 5 6 21 6"/>'
    '<path d="M19 6l-2 14a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2L5 6"/>'
    '<path d="M10 11v6"/><path d="M14 11v6"/></svg>';

const _externalLink =
    '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" '
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" '
    'stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>'
    '<polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/>'
    '</svg>';

const _googleG =
    '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" '
    'viewBox="0 0 24 24">'
    '<path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 '
    '1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>'
    '<path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 '
    '1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>'
    '<path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07'
    'H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>'
    '<path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 '
    '1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>';

// Tomato mark — derived from the app-icon master SVG, with the cream background
// rect and drop shadow removed and rgba() colors rewritten as fill/stroke
// opacity so flutter_svg renders them. viewBox cropped to the tomato + calyx.
const _tomatoMark =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="120 64 784 786">'
    '<defs><radialGradient id="ts" cx="35%" cy="30%" r="85%">'
    '<stop offset="0%" stop-color="#FFC896" stop-opacity="0.20"/>'
    '<stop offset="55%" stop-color="#FFFFFF" stop-opacity="0"/>'
    '<stop offset="100%" stop-color="#781E0F" stop-opacity="0.35"/>'
    '</radialGradient></defs>'
    '<path d="M 512 240 C 762 240 880 420 880 580 C 880 760 720 830 512 830 '
    'C 304 830 144 760 144 580 C 144 420 262 240 512 240 Z" fill="#D8513A"/>'
    '<path d="M 512 240 C 762 240 880 420 880 580 C 880 760 720 830 512 830 '
    'C 304 830 144 760 144 580 C 144 420 262 240 512 240 Z" fill="url(#ts)"/>'
    '<g stroke="#962814" stroke-opacity="0.18" stroke-width="4" fill="none" '
    'stroke-linecap="round">'
    '<path d="M 350 320 Q 320 540 380 800"/>'
    '<path d="M 670 320 Q 700 540 640 800"/></g>'
    '<ellipse cx="370" cy="370" rx="100" ry="60" transform="rotate(-30 370 370)" '
    'fill="#FFFFFF" fill-opacity="0.20"/>'
    '<ellipse cx="340" cy="350" rx="50" ry="22" transform="rotate(-30 340 350)" '
    'fill="#FFFFFF" fill-opacity="0.32"/>'
    '<g transform="translate(512 260)">'
    '<path d="M 0 0 L -120 -90 Q -130 -150 -90 -180 Q -40 -160 -10 -90 Z" fill="#1F4D38"/>'
    '<path d="M 0 0 L 120 -90 Q 130 -150 90 -180 Q 40 -160 10 -90 Z" fill="#1F4D38"/>'
    '<path d="M 0 0 L -160 -50 Q -200 -110 -160 -150 Q -100 -130 -50 -60 Z" fill="#2D6A4F"/>'
    '<path d="M 0 0 L 160 -50 Q 200 -110 160 -150 Q 100 -130 50 -60 Z" fill="#2D6A4F"/>'
    '<path d="M 0 0 L -50 -120 Q 0 -180 50 -120 L 0 0 Z" fill="#3A8060"/>'
    '<path d="M -50 -110 Q 0 -160 40 -120" stroke="#FFFFFF" stroke-opacity="0.25" '
    'stroke-width="6" fill="none" stroke-linecap="round"/>'
    '<rect x="-12" y="-150" width="24" height="40" rx="6" fill="#3A8060"/></g></svg>';
