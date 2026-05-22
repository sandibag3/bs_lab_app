import 'package:flutter/material.dart';

@immutable
class LabmatePalette extends ThemeExtension<LabmatePalette> {
  final Color appBackground;
  final Color panel;
  final Color panelAlt;
  final Color sidebar;
  final Color border;
  final Color selected;
  final Color mutedText;
  final Color subtleText;
  final Color warning;
  final Color danger;
  final Color success;

  const LabmatePalette({
    required this.appBackground,
    required this.panel,
    required this.panelAlt,
    required this.sidebar,
    required this.border,
    required this.selected,
    required this.mutedText,
    required this.subtleText,
    required this.warning,
    required this.danger,
    required this.success,
  });

  @override
  LabmatePalette copyWith({
    Color? appBackground,
    Color? panel,
    Color? panelAlt,
    Color? sidebar,
    Color? border,
    Color? selected,
    Color? mutedText,
    Color? subtleText,
    Color? warning,
    Color? danger,
    Color? success,
  }) {
    return LabmatePalette(
      appBackground: appBackground ?? this.appBackground,
      panel: panel ?? this.panel,
      panelAlt: panelAlt ?? this.panelAlt,
      sidebar: sidebar ?? this.sidebar,
      border: border ?? this.border,
      selected: selected ?? this.selected,
      mutedText: mutedText ?? this.mutedText,
      subtleText: subtleText ?? this.subtleText,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      success: success ?? this.success,
    );
  }

  @override
  LabmatePalette lerp(ThemeExtension<LabmatePalette>? other, double t) {
    if (other is! LabmatePalette) return this;

    return LabmatePalette(
      appBackground: Color.lerp(appBackground, other.appBackground, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelAlt: Color.lerp(panelAlt, other.panelAlt, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      border: Color.lerp(border, other.border, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension LabmateThemeContext on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  LabmatePalette get labmate {
    return Theme.of(this).extension<LabmatePalette>()!;
  }
}

class LabmateTheme {
  static const Color _darkPrimary = Color(0xFF14B8A6);
  static const Color _darkSecondary = Color(0xFF38BDF8);
  static const Color _darkBackground = Color(0xFF0F172A);
  static const Color _darkPanel = Color(0xFF1E293B);
  static const Color _darkPanelAlt = Color(0xFF111827);
  static const Color _darkBorder = Color(0x1FFFFFFF);

  static const Color _lightPrimary = Color(0xFF2563EB);
  static const Color _lightSecondary = Color(0xFF0891B2);
  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightPanel = Color(0xFFFFFFFF);
  static const Color _lightPanelAlt = Color(0xFFEFF4FA);
  static const Color _lightBorder = Color(0xFFD7DEE8);

  static ThemeData get dark {
    const palette = LabmatePalette(
      appBackground: _darkBackground,
      panel: _darkPanel,
      panelAlt: _darkPanelAlt,
      sidebar: _darkPanelAlt,
      border: _darkBorder,
      selected: Color(0x2214B8A6),
      mutedText: Colors.white70,
      subtleText: Colors.white60,
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFFB7185),
      success: Color(0xFF34D399),
    );

    return _base(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: _darkSecondary,
        surface: _darkPanel,
        onSurface: Colors.white,
        error: Color(0xFFFB7185),
      ),
      palette: palette,
    );
  }

  static ThemeData get light {
    const palette = LabmatePalette(
      appBackground: _lightBackground,
      panel: _lightPanel,
      panelAlt: _lightPanelAlt,
      sidebar: _lightPanel,
      border: _lightBorder,
      selected: Color(0xFFE0ECFF),
      mutedText: Color(0xFF334155),
      subtleText: Color(0xFF64748B),
      warning: Color(0xFFB45309),
      danger: Color(0xFFE11D48),
      success: Color(0xFF059669),
    );

    return _base(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: _lightSecondary,
        surface: _lightPanel,
        onSurface: Color(0xFF0F172A),
        error: Color(0xFFE11D48),
      ),
      palette: palette,
    );
  }

  static ThemeData _base({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required LabmatePalette palette,
  }) {
    final isDark = brightness == Brightness.dark;
    final foreground = colorScheme.onSurface;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: palette.appBackground,
      cardColor: palette.panel,
      dividerColor: palette.border,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      iconTheme: IconThemeData(color: foreground.withOpacity(0.72)),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: foreground,
        iconTheme: IconThemeData(color: foreground),
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: foreground, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: foreground),
        bodyMedium: TextStyle(color: foreground.withOpacity(0.78)),
        bodySmall: TextStyle(color: foreground.withOpacity(0.62)),
        labelLarge: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.panel,
        hintStyle: TextStyle(color: palette.subtleText),
        labelStyle: TextStyle(color: palette.subtleText),
        prefixIconColor: colorScheme.primary,
        suffixIconColor: palette.subtleText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground.withOpacity(0.78),
          side: BorderSide(color: palette.border),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: palette.subtleText),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.panelAlt,
        selectedColor: palette.selected,
        disabledColor: palette.panelAlt.withOpacity(0.6),
        labelStyle: TextStyle(color: foreground.withOpacity(0.74)),
        secondaryLabelStyle: TextStyle(color: foreground),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.panel,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: foreground.withOpacity(0.72),
          height: 1.4,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: foreground,
        titleTextStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        subtitleTextStyle: TextStyle(color: palette.subtleText),
      ),
    );
  }
}
