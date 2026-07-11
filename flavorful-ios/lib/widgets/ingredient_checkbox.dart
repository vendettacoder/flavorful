import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// 18×18 ingredient checkbox. Unchecked: white with a gray border. Checked:
/// green fill with an orange ✓.
class IngredientCheckbox extends StatelessWidget {
  const IngredientCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!checked),
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.checkbox),
          border: Border.all(
            color: checked ? AppColors.brandGreen : AppColors.checkboxBorder,
            width: 1.5,
          ),
        ),
        child: checked
            ? const Text(
                '✓',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandGreen,
                ),
              )
            : null,
      ),
    );
  }
}
