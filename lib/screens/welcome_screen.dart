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
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.appBackground,
              palette.panelAlt,
              palette.panel,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.science_rounded,
                size: 55,
                color: Color(0xFF14B8A6),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Labmate',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Welcome to Labmate\nYour chemistry lab partner.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: palette.mutedText,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (showDevWebDemo && onDevWebDemo != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    onDevWebDemo!();
                  },
                  icon: const Icon(Icons.web_asset_rounded),
                  label: const Text(
                    'Dev Web Demo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: const Color(0xFF5EEAD4),
                    side: const BorderSide(color: Color(0xFF5EEAD4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SignUpScreen(appState: appState),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: colorScheme.onSurface,
                  side: const BorderSide(color: Color(0xFF14B8A6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Login or create an account to continue to your lab.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: palette.subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
