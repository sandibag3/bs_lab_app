import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/labmate_theme.dart';
import 'app_settings_screen.dart';
import 'electronic_lab_manual_screen.dart';
import 'edit_profile_screen.dart';
import 'import_inventory_screen.dart';
import 'inventory_analytics_screen.dart';
import 'funds_dashboard_screen.dart';

class MoreScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onNavigateHome;

  const MoreScreen({super.key, required this.appState, this.onNavigateHome});

  void _showComingSoon(BuildContext context, String featureName) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text('$featureName coming soon')),
    );
  }

  Future<void> _handleBackOrHome(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
      return;
    }

    onNavigateHome?.call();
  }

  Widget buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    final titleColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.82)
        : theme.colorScheme.onSurfaceVariant;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(color: titleColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(title, style: titleStyle),
    );
  }

  Widget buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color accentColor = const Color(0xFF14B8A6),
    bool showChevron = true,
  }) {
    final theme = Theme.of(context);
    final palette = context.labmate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withValues(alpha: 0.14),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.subtleText,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showChevron)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: palette.subtleText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Sign Out?'),
          content: const Text(
            'This will sign you out of Firebase and clear the current lab session on this device.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Color(0xFFFB7185)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();
      await appState.clearSessionContext();

      if (!context.mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not sign out: $e')));
    }
  }

  void _openPersonalInformation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(title: const Text('Personal Information')),
            body: EditProfileScreen(appState: appState),
          );
        },
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AppSettingsScreen(appState: appState)),
    );
  }

  void _openLabManual(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(title: const Text('Electronic Lab Manual')),
            body: const ElectronicLabManualScreen(),
          );
        },
      ),
    );
  }

  void _openFundsDashboard(BuildContext context) {
    final activeLabId = appState.selectedLabId.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FundsDashboardScreen(labId: activeLabId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final canNavigateHome = onNavigateHome != null;

    return Scaffold(
      appBar: AppBar(
        leading: (canPop || canNavigateHome)
            ? IconButton(
                tooltip: canPop ? 'Back' : 'Back to Home',
                onPressed: () => _handleBackOrHome(context),
                icon: Icon(
                  canPop ? Icons.arrow_back_rounded : Icons.home_rounded,
                ),
              )
            : null,
        title: const Text('More'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSectionTitle(context, 'Inventory'),
              buildOptionCard(
                context: context,
                icon: Icons.insights_rounded,
                title: 'Inventory Analytics',
                subtitle:
                    'Read-only snapshot of chemical and consumables inventory health.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        return Scaffold(
                          appBar: AppBar(
                            title: const Text('Inventory Analytics'),
                          ),
                          body: const InventoryAnalyticsScreen(),
                        );
                      },
                    ),
                  );
                },
              ),
              buildOptionCard(
                context: context,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Funds / Expenditure',
                subtitle: 'View fund balances, utilization, and availability.',
                accentColor: const Color(0xFFF59E0B),
                onTap: () => _openFundsDashboard(context),
              ),
              buildSectionTitle(context, 'Import'),
              buildOptionCard(
                context: context,
                icon: Icons.file_upload_rounded,
                title: 'Import Inventory Excel',
                subtitle:
                    'Import your cleaned .xlsx inventory file into Firestore.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportInventoryScreen(),
                    ),
                  );
                },
              ),
              buildSectionTitle(context, 'General'),
              buildOptionCard(
                context: context,
                icon: Icons.person_outline_rounded,
                title: 'Personal Information',
                subtitle: 'Add or update your own optional profile details.',
                onTap: () => _openPersonalInformation(context),
              ),
              buildOptionCard(
                context: context,
                icon: Icons.settings_rounded,
                title: 'Settings',
                subtitle: 'Theme, app behavior, and preferences.',
                onTap: () => _openSettings(context),
              ),
              buildOptionCard(
                context: context,
                icon: Icons.description_rounded,
                title: 'Lab Manual',
                subtitle:
                    'Open lab guidance, SOP notes, and manual references.',
                accentColor: const Color(0xFF34D399),
                onTap: () => _openLabManual(context),
              ),
              buildOptionCard(
                context: context,
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'Get help, contact support, and FAQs.',
                showChevron: false,
                onTap: () => _showComingSoon(context, 'Help & Support'),
              ),
              buildSectionTitle(context, 'Data'),
              buildOptionCard(
                context: context,
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                subtitle: 'Save or recover important lab app data.',
                showChevron: false,
                onTap: () => _showComingSoon(context, 'Backup & Restore'),
              ),
              buildOptionCard(
                context: context,
                icon: Icons.admin_panel_settings_rounded,
                title: 'Admin Tools',
                subtitle: 'Manage advanced controls and permissions.',
                showChevron: false,
                onTap: () => _showComingSoon(context, 'Admin tools'),
              ),
              buildSectionTitle(context, 'Account'),
              buildOptionCard(
                context: context,
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle:
                    'Log out so you can sign in with a different email account.',
                accentColor: const Color(0xFFFB7185),
                showChevron: false,
                onTap: () => _signOut(context),
              ),
              buildSectionTitle(context, 'About'),
              buildOptionCard(
                context: context,
                icon: Icons.info_outline_rounded,
                title: 'About App',
                subtitle: 'Version, credits, and app information.',
                showChevron: false,
                onTap: () => _showComingSoon(context, 'About App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
