import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';

class AppSettingsScreen extends StatelessWidget {
  final AppState appState;

  const AppSettingsScreen({
    super.key,
    required this.appState,
  });

  String get _platformLabel {
    if (kIsWeb) return 'Web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final palette = context.labmate;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: palette.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              ...children,
            ],
          ),
        );
      },
    );
  }

  Widget _themeOption({
    required String title,
    required String subtitle,
    required ThemeMode value,
  }) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return RadioListTile<ThemeMode>(
          value: value,
          groupValue: appState.themeMode,
          onChanged: (themeMode) {
            if (themeMode == null) return;
            appState.saveThemeMode(themeMode);
          },
          activeColor: const Color(0xFF14B8A6),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final palette = context.labmate;

        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: context.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.subtleText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text('$featureName coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
        ),
      ),
      body: SafeArea(
        child: ResponsivePageContainer(
          maxWidth: 860,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(
                title: 'Appearance',
                children: [
                  _themeOption(
                    title: 'System default',
                    subtitle: 'Follow this device when supported.',
                    value: ThemeMode.system,
                  ),
                  _themeOption(
                    title: 'Light mode',
                    subtitle: 'Use a light app theme.',
                    value: ThemeMode.light,
                  ),
                  _themeOption(
                    title: 'Dark mode',
                    subtitle: 'Use the current Labmate dark theme.',
                    value: ThemeMode.dark,
                  ),
                ],
              ),
              _section(
                title: 'Layout',
                children: [
                  AnimatedBuilder(
                    animation: appState,
                    builder: (context, _) {
                      return SwitchListTile(
                        value: appState.compactDesktopMode,
                        onChanged: appState.saveCompactDesktopMode,
                        activeColor: const Color(0xFF14B8A6),
                        title: const Text(
                          'Compact desktop mode',
                        ),
                        subtitle: const Text(
                          'Saved locally. Wider layout wiring coming soon.',
                        ),
                      );
                    },
                  ),
                ],
              ),
              _section(
                title: 'Data & Export',
                children: [
                  _settingsRow(
                    icon: Icons.file_download_outlined,
                    title: 'Export settings',
                    subtitle: 'Prepare a local preferences export.',
                    onTap: () => _showComingSoon(context, 'Export settings'),
                  ),
                  _settingsRow(
                    icon: Icons.backup_outlined,
                    title: 'Backup lab data',
                    subtitle: 'Firebase-safe backup tools will be added later.',
                    onTap: () => _showComingSoon(context, 'Backup lab data'),
                  ),
                ],
              ),
              _section(
                title: 'About',
                children: [
                  _settingsRow(
                    icon: Icons.science_outlined,
                    title: 'App name',
                    subtitle: 'Labmate',
                  ),
                  _settingsRow(
                    icon: Icons.devices_outlined,
                    title: 'Platform',
                    subtitle: _platformLabel,
                  ),
                  _settingsRow(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    subtitle: 'Version information coming soon',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
