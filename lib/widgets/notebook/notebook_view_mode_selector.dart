import 'package:flutter/material.dart';

import '../../theme/labmate_theme.dart';

enum NotebookViewMode { small, medium, large, list }

NotebookViewMode notebookViewModeFromStorage(
  String? rawValue, {
  required NotebookViewMode fallback,
}) {
  for (final mode in NotebookViewMode.values) {
    if (mode.storageValue == rawValue) {
      return mode;
    }
  }
  return fallback;
}

extension NotebookViewModeX on NotebookViewMode {
  String get storageValue {
    switch (this) {
      case NotebookViewMode.small:
        return 'small';
      case NotebookViewMode.medium:
        return 'medium';
      case NotebookViewMode.large:
        return 'large';
      case NotebookViewMode.list:
        return 'list';
    }
  }

  String get label {
    switch (this) {
      case NotebookViewMode.small:
        return 'Small';
      case NotebookViewMode.medium:
        return 'Medium';
      case NotebookViewMode.large:
        return 'Large';
      case NotebookViewMode.list:
        return 'List';
    }
  }

  IconData get icon {
    switch (this) {
      case NotebookViewMode.small:
        return Icons.grid_view_rounded;
      case NotebookViewMode.medium:
        return Icons.grid_on_rounded;
      case NotebookViewMode.large:
        return Icons.view_module_rounded;
      case NotebookViewMode.list:
        return Icons.view_list_rounded;
    }
  }
}

class NotebookViewModeSelector extends StatelessWidget {
  final NotebookViewMode value;
  final ValueChanged<NotebookViewMode> onChanged;

  const NotebookViewModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: NotebookViewMode.values
          .map((mode) {
            final isSelected = mode == value;

            return Tooltip(
              message: '${mode.label} view',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF14B8A6).withValues(alpha: 0.16)
                        : palette.panelAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF14B8A6).withValues(alpha: 0.38)
                          : palette.border,
                    ),
                  ),
                  child: Icon(
                    mode.icon,
                    size: 17,
                    color: isSelected
                        ? const Color(0xFF5EEAD4)
                        : palette.subtleText,
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
