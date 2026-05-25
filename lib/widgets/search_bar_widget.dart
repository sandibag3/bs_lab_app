import 'package:flutter/material.dart';

import '../theme/labmate_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String hintText;
  final bool readOnly;
  final bool isFocused;
  final bool compact;
  final Widget? suffixIcon;
  final bool showClearButton;

  const SearchBarWidget({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.hintText = 'Search chemical by name, CAS, or label',
    this.readOnly = false,
    this.isFocused = false,
    this.compact = false,
    this.suffixIcon,
    this.showClearButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final borderRadius = BorderRadius.circular(compact ? 16 : 18);
    final searchBarHeight = compact ? 52.0 : 56.0;

    Widget buildField(BuildContext context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final showSuffix =
              suffixIcon != null &&
              constraints.maxWidth >= (compact ? 280 : 320);
          final textValue = controller?.value.text ?? '';
          final hasText = textValue.trim().isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: searchBarHeight,
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: borderRadius,
              border: Border.all(
                color: isFocused
                    ? colorScheme.primary.withValues(alpha: 0.55)
                    : palette.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isFocused ? 0.08 : 0.04,
                  ),
                  blurRadius: isFocused ? 14 : 8,
                  offset: Offset(0, isFocused ? 5 : 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: colorScheme.primary,
                  size: compact ? 19 : 21,
                ),
                SizedBox(width: compact ? 10 : 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: readOnly,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    onTap: onTap,
                    cursorColor: colorScheme.primary,
                    textAlignVertical: TextAlignVertical.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: compact ? 13.5 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: palette.subtleText,
                        fontSize: compact ? 13 : 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (hasText && showClearButton && !readOnly) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      controller?.clear();
                      onChanged?.call('');
                      focusNode?.requestFocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: compact ? 16 : 17,
                        color: palette.mutedText,
                      ),
                    ),
                  ),
                ],
                if (showSuffix) ...[const SizedBox(width: 10), suffixIcon!],
              ],
            ),
          );
        },
      );
    }

    if (controller == null) {
      return buildField(context);
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller!,
      builder: (context, value, child) => buildField(context),
    );
  }
}
