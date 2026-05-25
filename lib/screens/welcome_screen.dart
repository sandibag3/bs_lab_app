import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/labmate_theme.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final AppState appState;
  final bool showDevWebDemo;
  final Future<void> Function()? onDevWebDemo;

  const WelcomeScreen({
    super.key,
    required this.appState,
    this.showDevWebDemo = false,
    this.onDevWebDemo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout = constraints.maxWidth >= 700;
          final horizontalPadding = isWideLayout ? 24.0 : 16.0;
          final verticalPadding = isWideLayout ? 24.0 : 16.0;
          final minHeight = math.max(
            0.0,
            constraints.maxHeight - (verticalPadding * 2),
          );

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.alphaBlend(
                          colorScheme.primary.withValues(
                            alpha: isDark ? 0.12 : 0.05,
                          ),
                          palette.appBackground,
                        ),
                        palette.appBackground,
                        Color.alphaBlend(
                          colorScheme.secondary.withValues(
                            alpha: isDark ? 0.06 : 0.03,
                          ),
                          palette.appBackground,
                        ),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -36,
                        right: -24,
                        child: _WelcomeBackdropOrb(
                          size: 170,
                          color: colorScheme.primary.withValues(
                            alpha: isDark ? 0.12 : 0.08,
                          ),
                        ),
                      ),
                      Positioned(
                        left: -28,
                        bottom: 48,
                        child: _WelcomeBackdropOrb(
                          size: 135,
                          color: colorScheme.secondary.withValues(
                            alpha: isDark ? 0.09 : 0.05,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 112,
                        left: 24,
                        child: Icon(
                          Icons.bubble_chart_rounded,
                          size: 42,
                          color: colorScheme.primary.withValues(
                            alpha: isDark ? 0.08 : 0.06,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: palette.panel.withValues(
                              alpha: isDark ? 0.92 : 0.96,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: palette.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.28 : 0.08,
                                ),
                                blurRadius: 32,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  height: 78,
                                  width: 78,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.primary.withValues(
                                      alpha: isDark ? 0.18 : 0.10,
                                    ),
                                    border: Border.all(
                                      color: colorScheme.primary.withValues(
                                        alpha: isDark ? 0.22 : 0.16,
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.science_rounded,
                                        size: 34,
                                        color: colorScheme.primary,
                                      ),
                                      Positioned(
                                        right: 15,
                                        bottom: 15,
                                        child: Icon(
                                          Icons.bubble_chart_rounded,
                                          size: 14,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Labmate',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Welcome to Labmate',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your chemistry lab partner.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: palette.mutedText,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LoginScreen(
                                          appState: appState,
                                          showDevWebDemo: showDevWebDemo,
                                          onDevWebDemo: onDevWebDemo,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Login'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (showDevWebDemo && onDevWebDemo != null) ...[
                                SizedBox(
                                  height: 50,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      onDevWebDemo!();
                                    },
                                    icon: const Icon(
                                      Icons.web_asset_rounded,
                                      size: 18,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colorScheme.secondary,
                                      side: BorderSide(
                                        color: colorScheme.secondary.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    label: const Text('Dev Web Demo'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              SizedBox(
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SignUpScreen(appState: appState),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text('Sign Up'),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Login or create an account to continue to your lab.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.subtleText,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeBackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _WelcomeBackdropOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
