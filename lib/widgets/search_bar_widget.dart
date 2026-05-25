import 'package:flutter/material.dart';

import '../theme/labmate_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
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
    required this.controller,
    required this.focusNode,
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
    const searchBarHeight = 48.0;

    Widget buildField(BuildContext context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final showSuffix =
              suffixIcon != null &&
              constraints.maxWidth >= (compact ? 280 : 320);
          final textValue = controller.value.text;
          final hasText = textValue.trim().isNotEmpty;

          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              if (!focusNode.hasFocus) {
                focusNode.requestFocus();
              }
              onTap?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              height: searchBarHeight,
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
              child: SizedBox(
                height: searchBarHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: Icon(
                          Icons.search_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          if (!hasText)
                            IgnorePointer(
                              child: Text(
                                hintText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          EditableText(
                            controller: controller,
                            focusNode: focusNode,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w400,
                            ),
                            cursorColor: colorScheme.primary,
                            backgroundCursorColor:
                                colorScheme.surfaceContainerHighest,
                            selectionColor: colorScheme.primary.withValues(
                              alpha: 0.20,
                            ),
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.search,
                            maxLines: 1,
                            readOnly: readOnly,
                            onChanged: onChanged,
                            onSubmitted: onSubmitted,
                            cursorHeight: 18,
                            cursorWidth: 1.5,
                          ),
                        ],
                      ),
                    ),
                    if (hasText && showClearButton && !readOnly)
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              controller.clear();
                              onChanged?.call('');
                              focusNode.requestFocus();
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
                        ),
                      ),
                    if (showSuffix)
                      SizedBox(
                        width: 94,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: suffixIcon!,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) => buildField(context),
    );
  }
}
