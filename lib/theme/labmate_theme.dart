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
  static const Color _darkMutedText = Color(0xFFD8E0EB);
  static const Color _darkSubtleText = Color(0xFFB7C3D4);

  static const Color _lightPrimary = Color(0xFF2563EB);
  static const Color _lightSecondary = Color(0xFF0891B2);
  static const Color _lightBackground = Color(0xFFF5F7FA);
  static const Color _lightPanel = Color(0xFFFFFFFF);
  static const Color _lightPanelAlt = Color(0xFFEFF4FA);
  static const Color _lightBorder = Color(0xFFD7DEE8);
  static const Color _lightMutedText = Color(0xFF334155);
  static const Color _lightSubtleText = Color(0xFF475569);

  static ThemeData get dark {
    const palette = LabmatePalette(
      appBackground: _darkBackground,
      panel: _darkPanel,
      panelAlt: _darkPanelAlt,
      sidebar: _darkPanelAlt,
      border: _darkBorder,
      selected: Color(0x2214B8A6),
      mutedText: _darkMutedText,
      subtleText: _darkSubtleText,
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
      mutedText: _lightMutedText,
      subtleText: _lightSubtleText,
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
    final textTheme = _buildTextTheme(
      foreground: foreground,
      mutedText: palette.mutedText,
      subtleText: palette.subtleText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: palette.appBackground,
      cardColor: palette.panel,
      dividerColor: palette.border,
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: palette.mutedText),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: foreground,
        iconTheme: IconThemeData(color: foreground),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        toolbarTextStyle: textTheme.bodyMedium?.copyWith(color: foreground),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.panel,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.subtleText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: palette.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: palette.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.error,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: colorScheme.primary,
        suffixIconColor: palette.mutedText,
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
          textStyle: textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: palette.border),
          textStyle: textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
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
        disabledColor: palette.panelAlt.withValues(alpha: 0.72),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: palette.mutedText,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.panel,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.mutedText,
          height: 1.4,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF111827)
            : const Color(0xFF1E293B),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.mutedText,
        textColor: foreground,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: palette.mutedText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Color foreground,
    required Color mutedText,
    required Color subtleText,
  }) {
    return TextTheme(
      displayLarge: _textStyle(foreground, 36, FontWeight.w700, height: 1.1),
      displayMedium: _textStyle(foreground, 32, FontWeight.w700, height: 1.12),
      displaySmall: _textStyle(foreground, 28, FontWeight.w700, height: 1.15),
      headlineLarge: _textStyle(foreground, 24, FontWeight.w700, height: 1.2),
      headlineMedium: _textStyle(foreground, 21, FontWeight.w700, height: 1.22),
      headlineSmall: _textStyle(foreground, 18, FontWeight.w700, height: 1.25),
      titleLarge: _textStyle(foreground, 20, FontWeight.w700, height: 1.25),
      titleMedium: _textStyle(foreground, 16, FontWeight.w700, height: 1.28),
      titleSmall: _textStyle(foreground, 14, FontWeight.w600, height: 1.3),
      bodyLarge: _textStyle(foreground, 15, FontWeight.w500, height: 1.42),
      bodyMedium: _textStyle(foreground, 14, FontWeight.w500, height: 1.42),
      bodySmall: _textStyle(mutedText, 13, FontWeight.w500, height: 1.38),
      labelLarge: _textStyle(foreground, 14, FontWeight.w700, height: 1.2),
      labelMedium: _textStyle(mutedText, 12.5, FontWeight.w600, height: 1.2),
      labelSmall: _textStyle(subtleText, 11.5, FontWeight.w600, height: 1.2),
    );
  }

  static TextStyle _textStyle(
    Color color,
    double size,
    FontWeight weight, {
    double? height,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
    );
  }
}
