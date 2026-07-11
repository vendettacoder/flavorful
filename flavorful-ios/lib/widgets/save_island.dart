import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/providers.dart';
import '../theme/tokens.dart';
import 'app_icons.dart';

/// The Cookbook "save island": an elevated parchment card with a soft paper
/// highlight and scattered olive sprigs, a sage badge + copy, and a white URL
/// input with an inset sage Save button. Drives the same add-recipe states as
/// the old paste field.
class SaveIsland extends StatefulWidget {
  const SaveIsland({
    super.key,
    required this.controller,
    required this.status,
    required this.onSubmitted,
    required this.onRetry,
    required this.onSave,
    this.pastedUrl,
    this.errorMessage,
  });

  final TextEditingController controller;
  final AddStatus status;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onRetry;
  final VoidCallback onSave;
  final String? pastedUrl;
  final String? errorMessage;

  @override
  State<SaveIsland> createState() => _SaveIslandState();
}

class _SaveIslandState extends State<SaveIsland> {
  bool get _isSaving => widget.status == AddStatus.saving;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceParchment,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderParchmentStrong),
        boxShadow: AppShadows.parchmentIsland,
      ),
      clipBehavior: Clip.antiAlias, // clip the pattern layers to the card
      child: Stack(
        children: [
          // Layer A · paper highlight: top-left glow + warm bottom-right ambient.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.6, -0.7),
                    radius: 0.9,
                    colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.7, 0.8),
                    radius: 0.7,
                    colors: [Color(0x14B48C50), Color(0x00B48C50)],
                    stops: [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          // Layer B · scattered olive sprigs, 32% opacity, decorative.
          const Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.32,
                child: CustomPaint(
                  painter: _SprigPatternPainter(color: AppColors.brandOlive),
                ),
              ),
            ),
          ),
          // Content.
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerRow(),
                const SizedBox(height: 14),
                _inputField(),
                if (widget.status == AddStatus.error) _errorRow(),
              ],
            ),
          ),
          // Thin inset white rim — reads as printed-card sheen along the edge.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x99FFFFFF)), // 0.6
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.brandGreen, // sage badge pops against the cream
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.sageBadge,
          ),
          alignment: Alignment.center,
          child: AppIcons.chainLink(size: 18, color: AppColors.onGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Save a recipe',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  letterSpacing: AppText.tracking(-0.015, 15),
                  color: AppColors.parchmentHeading,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Paste any recipe URL',
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  letterSpacing: AppText.tracking(-0.005, 12),
                  color: AppColors.parchmentSub,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inputField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderParchment),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 52, // match the search field
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _isSaving
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.pastedUrl ?? widget.controller.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.pastedUrl().copyWith(fontSize: 13),
                        ),
                      )
                    : TextField(
                        controller: widget.controller,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2048),
                        ],
                        onSubmitted: widget.onSubmitted,
                        style: AppText.body().copyWith(fontSize: 14),
                        cursorColor: AppColors.brandGreen,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'https://...',
                          hintStyle: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.parchmentPlaceholder,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: _saveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isSaving ? null : widget.onSave,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _isSaving
              ? const Color(0xFF6E9683) // muted sage while saving
              : AppColors.brandGreen,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: _isSaving
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.onGreen),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: AppText.tracking(-0.005, 13),
                      color: AppColors.onGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AppIcons.arrowRight(size: 13, color: AppColors.onGreen),
                ],
              ),
      ),
    );
  }

  Widget _errorRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.errorMessage ??
                  "Couldn't read that page. Try a different URL.",
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.accentOrange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onRetry,
            child: Text(
              'Try again',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One scattered sprig: position (as a fraction of the card), rotation, and a
/// size variant (0 = small, 1 = medium, 2 = large).
class _Sprig {
  const _Sprig(this.fx, this.fy, this.angle, this.variant);
  final double fx;
  final double fy;
  final double angle;
  final int variant;
}

/// Paints ~10 hand-placed sprigs (curved stem + alternating leaves), clustered
/// toward the edges/corners with the mid-center kept clearer so the copy stays
/// legible. Painted in [color] at full strength — the layer's opacity is
/// applied by the wrapping [Opacity], matching the spec's single pattern layer.
class _SprigPatternPainter extends CustomPainter {
  const _SprigPatternPainter({required this.color});

  final Color color;

  static const _sprigs = <_Sprig>[
    _Sprig(0.05, 0.14, -40, 1),
    _Sprig(0.08, 0.72, 30, 2),
    _Sprig(0.16, 0.90, -20, 0),
    _Sprig(0.92, 0.12, -30, 1),
    _Sprig(0.95, 0.55, 45, 0),
    _Sprig(0.86, 0.88, -15, 2),
    _Sprig(0.78, 0.22, 60, 0),
    _Sprig(0.30, 0.86, 20, 1),
    _Sprig(0.66, 0.90, -50, 0),
    _Sprig(0.48, 0.10, 35, 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    for (final s in _sprigs) {
      canvas.save();
      canvas.translate(s.fx * size.width, s.fy * size.height);
      canvas.rotate(s.angle * math.pi / 180);
      _drawSprig(canvas, s.variant, fill);
      canvas.restore();
    }
  }

  void _drawSprig(Canvas canvas, int variant, Paint fill) {
    // (stemLen, leafCount, rx, ry, strokeWidth) per variant.
    late final double stemLen, rx, ry, sw;
    late final int leaves;
    switch (variant) {
      case 2: // large
        stemLen = 40;
        leaves = 4;
        rx = 7;
        ry = 3;
        sw = 1.2;
      case 1: // medium
        stemLen = 28;
        leaves = 3;
        rx = 5.5;
        ry = 2.4;
        sw = 1.0;
      default: // small
        stemLen = 16;
        leaves = 2;
        rx = 4;
        ry = 1.8;
        sw = 0.8;
    }

    // Curved stem, growing downward from the origin.
    final stem = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(0, stemLen / 2, 1, stemLen);
    canvas.drawPath(
      stem,
      Paint()
        ..color = fill.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );

    // Leaves alternate ±30° down the stem.
    for (var i = 0; i < leaves; i++) {
      final y = stemLen * (i + 1) / (leaves + 1);
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (rx + 0.5);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(side * 30 * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        fill,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SprigPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
