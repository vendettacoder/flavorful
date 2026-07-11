import 'package:flutter/widgets.dart';

/// Design tokens — the single source of truth for color, type, spacing,
/// radius, and shadow. Mirrors `design_handoff_flutter_ios/README.md` §5.
///
/// CSS letter-spacing is in `em`; Flutter wants logical pixels. Convert with
/// [AppText.tracking] = em * fontSize.
class AppColors {
  AppColors._();

  static const bgPage = Color(0xFFFAFAF8); // app background
  static const bgBeige = Color(0xFFF5EDD8); // sign-in sheet, profile sheet
  static const bgBeigeBorder = Color(0xFFE5DBB8); // beige border

  // Library recipe cards — soft sage.
  static const bgSageCard = Color(0xFFDCE9D9);
  static const bgSageCardBorder = Color(0xFFC4D9BE);
  static const bgNotes = Color(0xFFF4F1EA); // notes-from-page band
  static const surface = Color(0xFFFFFFFF); // url field, unchecked checkbox

  static const brandGreen = Color(0xFF2D6A4F); // hero, primary buttons, checks

  // Cookbook screen redesign (sage "save island" + search pill).
  static const brandSageDark = Color(0xFF1F4D38); // inset Save button, deep sage
  static const searchFill = Color(0xFFE6EEE4); // filled search pill
  static const sageMuted = Color(0xFF7A8B78); // cookbook count, search icon
  static const sagePlaceholder = Color(0xFF8A9588); // search placeholder text
  static const islandPlaceholder = Color(0xFFA8AFA5); // url input placeholder

  // Parchment "cookbook" save island (v2).
  static const surfaceParchment = Color(0xFFF5EBD0); // island background
  static const borderParchment = Color(0xFFE5D6AF); // input container border
  static const borderParchmentStrong = Color(0xFFDBC582); // island edge (deeper)
  static const parchmentHeading = Color(0xFF3D2E15); // "Save a recipe"
  static const parchmentSub = Color(0xFF8A7548); // subheading
  static const parchmentPlaceholder = Color(0xFFB8A87A); // url placeholder
  static const brandOlive = Color(0xFF7A8B4E); // scattered sprig color
  static const accentOrange = Color(0xFFD4663A); // brand dot, eyebrows, CTAs
  static const accentOrangeDark = Color(0xFF9F4A26); // avatar gradient end
  static const danger = Color(0xFFC0392B); // destructive actions (log out)

  static const textPrimary = Color(0xFF2A2520);
  static const textSecondary = Color(0xFF57514A); // darker warm gray, more legible
  static const textTertiary = Color(0xFF8A857D); // darker tertiary for labels/meta
  static const textInputPlaceholder = Color(0xFFA8A8A8);

  static const divider = Color(0xFFE8E6E1);
  static const dividerSoft = Color(0xFFF0EEE8);
  static const inputBorder = Color(0xFFE2DFD7);
  static const checkboxBorder = Color(0xFFC8C5BD);

  /// White-on-green is warm off-white, not pure #FFFFFF.
  static const onGreen = Color(0xFFFAFAF8);

  // rgba shadow tints
  static const _cardTintStrong = Color(0x1F503214); // rgba(80,50,20,0.12)
  static const _cardTintSoft = Color(0x0D503214); // rgba(80,50,20,0.05)
  // sage-tinted shadow for the library cards
  static const _sageTintStrong = Color(0x1F2D5032); // rgba(45,80,50,0.12)
  static const _sageTintSoft = Color(0x0D2D5032); // rgba(45,80,50,0.05)
}

class AppSpacing {
  AppSpacing._();

  /// Horizontal content edge padding on phone.
  static const edge = 20.0;

  /// Top-bar row horizontal padding.
  static const topBar = 16.0;

  /// Bottom reservation for the home indicator on scrollable content.
  static const homeIndicator = 90.0;
}

class AppRadii {
  AppRadii._();

  static const card = 10.0;
  static const input = 10.0;
  static const button = 8.0;
  static const stepper = 4.0;
  static const checkbox = 4.0;
  static const brandSquare = 2.0;
  static const sheet = 24.0;
}

class AppShadows {
  AppShadows._();

  /// Warm shadow under beige cards on the cream background.
  static const card = <BoxShadow>[
    BoxShadow(
      color: AppColors._cardTintStrong,
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -6,
    ),
    BoxShadow(
      color: AppColors._cardTintSoft,
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// Sage-tinted shadow under the library recipe cards.
  static const sageCard = <BoxShadow>[
    BoxShadow(
      color: AppColors._sageTintStrong,
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -6,
    ),
    BoxShadow(
      color: AppColors._sageTintSoft,
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// Parchment "save island" — long amber drop shadow (the inset white rim is
  /// drawn separately as an overlay border, since BoxShadow has no inset mode).
  /// 0 24px 44px -20px rgba(80,50,15,0.30)
  static const parchmentIsland = <BoxShadow>[
    BoxShadow(
      color: Color(0x4D50320F),
      offset: Offset(0, 24),
      blurRadius: 44,
      spreadRadius: -20,
    ),
  ];

  /// Sage badge inside the parchment island.
  /// 0 4px 10px -2px rgba(31,77,56,0.35)
  static const sageBadge = <BoxShadow>[
    BoxShadow(
      color: Color(0x591F4D38),
      offset: Offset(0, 4),
      blurRadius: 10,
      spreadRadius: -2,
    ),
  ];

  /// URL paste field at rest.
  static const urlResting = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F000000), // rgba(0,0,0,0.06)
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: -2,
    ),
  ];

  /// URL paste field focused — the terracotta ring.
  static const urlActiveRing = <BoxShadow>[
    BoxShadow(
      color: Color(0x1AD4663A), // rgba(212,102,58,0.10)
      blurRadius: 0,
      spreadRadius: 4,
    ),
  ];

  /// Green Continue-with-Google button.
  static const googleButton = <BoxShadow>[
    BoxShadow(
      color: Color(0x592D6A4F), // rgba(45,106,79,0.35)
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -6,
    ),
  ];

  /// Orange Original-page CTA on the detail screen.
  static const originalPageCta = <BoxShadow>[
    BoxShadow(
      color: Color(0x59D4663A), // rgba(212,102,58,0.35)
      offset: Offset(0, 6),
      blurRadius: 14,
      spreadRadius: -4,
    ),
  ];

  /// Destructive (Log out) button.
  static const dangerButton = <BoxShadow>[
    BoxShadow(
      color: Color(0x59C0392B), // rgba(192,57,43,0.35)
      offset: Offset(0, 6),
      blurRadius: 14,
      spreadRadius: -4,
    ),
  ];
}

/// Bundled font families (see pubspec `flutter > fonts`).
class AppFonts {
  AppFonts._();
  static const sans = 'InterTight'; // matches the web
  static const mono = 'GeistMono'; // mono accents keep Geist Mono for contrast
}

/// Typography. Two bundled families: Geist (sans) and Geist Mono.
class AppText {
  AppText._();

  /// CSS em letter-spacing → Flutter logical pixels.
  static double tracking(double em, double fontSize) => em * fontSize;

  static TextStyle _sans({
    required double size,
    required FontWeight weight,
    double? height,
    double? letterSpacing,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _mono({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // ── Sans roles ─────────────────────────────────────────────
  static TextStyle hero({Color color = AppColors.onGreen}) => _sans(
        size: 46,
        weight: FontWeight.w700,
        height: 0.98,
        letterSpacing: tracking(-0.035, 46),
        color: color,
      );

  static TextStyle signInTitle() => _sans(
        size: 32,
        weight: FontWeight.w700,
        height: 1.0,
        letterSpacing: tracking(-0.025, 32),
      );

  static TextStyle recipeTitle() => _sans(
        size: 38,
        weight: FontWeight.w700,
        height: 1.0,
        letterSpacing: tracking(-0.03, 38),
      );

  static TextStyle pageTitle() => _sans(
        size: 32,
        weight: FontWeight.w700,
        letterSpacing: tracking(-0.025, 32),
      );

  static TextStyle sectionHeader() => _sans(
        size: 18,
        weight: FontWeight.w700,
        letterSpacing: tracking(-0.015, 18),
        color: AppColors.brandGreen,
      );

  static TextStyle cardTitle() => _sans(
        size: 18,
        weight: FontWeight.w700,
        height: 1.25,
        letterSpacing: tracking(-0.015, 18),
      );

  static TextStyle methodBody() =>
      _sans(size: 15, weight: FontWeight.w500, height: 1.55);

  static TextStyle body() =>
      _sans(size: 14, weight: FontWeight.w500, height: 1.5);

  static TextStyle ingredient() =>
      _sans(size: 15, weight: FontWeight.w500, height: 1.4);

  static TextStyle cardDescription() => _sans(
        size: 13,
        weight: FontWeight.w500,
        height: 1.45,
        letterSpacing: tracking(-0.005, 13),
        color: AppColors.textSecondary,
      );

  static TextStyle notesItem() =>
      _sans(size: 13, weight: FontWeight.w500, height: 1.55);

  static TextStyle statValue() => _sans(size: 18, weight: FontWeight.w600);

  static TextStyle statLabel() => _sans(
        size: 11,
        weight: FontWeight.w700,
        letterSpacing: tracking(0.08, 11),
        color: AppColors.textSecondary,
      );

  static TextStyle heroParagraph() => _sans(
        size: 16,
        weight: FontWeight.w400,
        height: 1.5,
        color: const Color(0xB3FAFAF8), // rgba(250,250,248,0.7)
      );

  /// Library section label ("NEW RECIPE", "YOUR RECIPES") — bolder + darker
  /// than [eyebrow] so sections read clearly.
  static TextStyle sectionLabel({Color color = AppColors.textPrimary}) => _sans(
        size: 13,
        weight: FontWeight.w700,
        letterSpacing: tracking(0.06, 13),
        color: color,
      );

  /// "SAVING RECIPE" / "YOUR LIBRARY" eyebrow.
  static TextStyle eyebrow({
    Color color = AppColors.textTertiary,
    FontWeight weight = FontWeight.w500,
  }) =>
      _sans(
        size: 11,
        weight: weight,
        letterSpacing: tracking(0.12, 11),
        color: color,
      );

  static TextStyle urlPlaceholder() => _sans(
        size: 14,
        weight: FontWeight.w400,
        color: AppColors.textInputPlaceholder,
      );

  // ── Mono roles ─────────────────────────────────────────────
  static TextStyle sourceEyebrow() => _mono(
        size: 10,
        weight: FontWeight.w500,
        letterSpacing: tracking(0.08, 10),
        color: AppColors.accentOrange,
      );

  static TextStyle stepNumber() => _mono(
        size: 13,
        weight: FontWeight.w600,
        color: AppColors.accentOrange,
      );

  static TextStyle metaMono() => _mono(
        size: 11,
        weight: FontWeight.w400,
        color: AppColors.textTertiary,
      );

  static TextStyle notesArrow() => _mono(
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.accentOrange,
      );

  static TextStyle pastedUrl() => _mono(
        size: 11,
        weight: FontWeight.w400,
        color: AppColors.textPrimary,
      );
}
