import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/providers.dart';
import '../theme/tokens.dart';
import 'app_icons.dart';

/// The library URL paste field. Renders four states driven by [status]:
///
///  * idle    — editable field with the "Paste a recipe URL" placeholder
///  * focused — terracotta border + ring (while the field has focus)
///  * saving  — pasted URL in mono + a "Fetching recipe…" spinner row
///  * error   — pasted URL in mono + an error message and a "Try again" button
class UrlPasteField extends StatefulWidget {
  const UrlPasteField({
    super.key,
    required this.controller,
    required this.status,
    required this.onSubmitted,
    required this.onRetry,
    this.onSave,
    this.pastedUrl,
    this.errorMessage,
  });

  final TextEditingController controller;
  final AddStatus status;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onRetry;
  final VoidCallback? onSave; // tapping Save inside the field container
  final String? pastedUrl;
  final String? errorMessage;

  @override
  State<UrlPasteField> createState() => _UrlPasteFieldState();
}

class _UrlPasteFieldState extends State<UrlPasteField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _focused) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isSaving => widget.status == AddStatus.saving;
  bool get _active => _focused;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(
          color: _active ? AppColors.accentOrange : AppColors.inputBorder,
          width: 1.5,
        ),
        boxShadow: _active ? AppShadows.urlActiveRing : AppShadows.urlResting,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _inputRow(),
          if (widget.status == AddStatus.error) _errorRow(),
        ],
      ),
    );
  }

  Widget _inputRow() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: AppIcons.chainLink(size: 18),
          ),
          Expanded(
            child: _isSaving
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      widget.pastedUrl ?? widget.controller.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.pastedUrl(),
                    ),
                  )
                : TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    inputFormatters: [LengthLimitingTextInputFormatter(2048)],
                    onSubmitted: widget.onSubmitted,
                    style: AppText.body(),
                    cursorColor: AppColors.accentOrange,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'https://...',
                      hintStyle: AppText.urlPlaceholder(),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
          ),
          // Save button — always visible. Dark green at rest; lighter + spinner
          // while saving so it's clear it can't be tapped.
          if (widget.onSave != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isSaving ? null : widget.onSave,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                width: 72,
                alignment: Alignment.center,
                color: _isSaving
                    ? const Color(0xFFA8C5A3) // light sage — disabled
                    : AppColors.brandGreen, // dark green — ready
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.onGreen),
                        ),
                      )
                    : Text(
                        'Save',
                        style: AppText.body().copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onGreen,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(top: BorderSide(color: AppColors.dividerSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.errorMessage ??
                  "Couldn't read that page. Try a different URL.",
              style: AppText.body().copyWith(
                fontSize: 13,
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
              style: AppText.body().copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brandGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

