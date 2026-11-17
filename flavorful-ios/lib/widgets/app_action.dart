// Keep the shared app compatible with the current native Flutter SDK.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Keyboard and mouse support for the existing custom controls.
class AppAction extends StatefulWidget {
  const AppAction({
    super.key,
    required this.child,
    this.onTap,
    this.label,
    this.checked,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool? checked;

  @override
  State<AppAction> createState() => _AppActionState();
}

class _AppActionState extends State<AppAction> {
  bool _highlight = false;

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    button: widget.checked == null,
    checked: widget.checked,
    enabled: widget.onTap != null,
    onTap: widget.onTap,
    child: FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onShowFocusHighlight: (value) => setState(() => _highlight = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.onTap,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: _highlight
                ? Border.all(color: AppColors.accentOrange, width: 2)
                : null,
          ),
          child: widget.child,
        ),
      ),
    ),
  );
}
