import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// The `[−] 4 [+]` servings control. `−` is a white square, `+` is green.
/// Clamped to [min]..[max].
class ServingsStepper extends StatelessWidget {
  const ServingsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 24,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          glyph: '−', // minus sign
          semanticLabel: 'Decrease servings',
          background: AppColors.surface,
          border: AppColors.divider,
          glyphColor: AppColors.textSecondary,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 40, // fits double digits (e.g. 10) on one line
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppText.statValue().copyWith(fontSize: 22),
          ),
        ),
        const SizedBox(width: 16),
        _StepperButton(
          glyph: '+',
          semanticLabel: 'Increase servings',
          background: AppColors.brandGreen,
          glyphColor: AppColors.onGreen,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.glyph,
    required this.semanticLabel,
    required this.background,
    required this.glyphColor,
    required this.enabled,
    required this.onTap,
    this.border,
  });

  final String glyph;
  final String semanticLabel;
  final Color background;
  final Color glyphColor;
  final Color? border;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Container(
            width: 44, // accessible tap target (Apple HIG minimum)
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: border == null ? null : Border.all(color: border!),
            ),
            child: Text(
              glyph,
              style: TextStyle(
                fontSize: 24,
                height: 1.0,
                color: glyphColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
