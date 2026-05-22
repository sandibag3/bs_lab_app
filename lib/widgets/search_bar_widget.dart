import 'package:flutter/material.dart';
import '../theme/labmate_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final VoidCallback? onTap;

  const SearchBarWidget({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: Container(
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search chemical by name, CAS, or functional group',
              hintStyle: TextStyle(color: palette.subtleText),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: colorScheme.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: palette.panel,
            ),
          ),
        ),
      ),
    );
  }
}
