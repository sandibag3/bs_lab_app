import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'edit_profile_screen.dart';
import 'import_inventory_screen.dart';

class MoreScreen extends StatelessWidget {
  final AppState appState;

  const MoreScreen({super.key, required this.appState});

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.14),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showChevron)
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.white38,
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
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This will sign you out of Firebase and clear the current lab session on this device.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
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
            appBar: AppBar(
              title: const Text(
                'Personal Information',
                style: TextStyle(color: Colors.white),
              ),
            ),
            body: EditProfileScreen(appState: appState),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionTitle('Import'),
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
            buildSectionTitle('General'),
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
            ),
            buildOptionCard(
              context: context,
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              subtitle: 'Get help, contact support, and FAQs.',
            ),
            buildSectionTitle('Data'),
            buildOptionCard(
              context: context,
              icon: Icons.backup_rounded,
              title: 'Backup & Restore',
              subtitle: 'Save or recover important lab app data.',
            ),
            buildOptionCard(
              context: context,
              icon: Icons.admin_panel_settings_rounded,
              title: 'Admin Tools',
              subtitle: 'Manage advanced controls and permissions.',
            ),
            buildSectionTitle('Account'),
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
            buildSectionTitle('About'),
            buildOptionCard(
              context: context,
              icon: Icons.info_outline_rounded,
              title: 'About App',
              subtitle: 'Version, credits, and app information.',
            ),
          ],
        ),
      ),
    );
  }
}
