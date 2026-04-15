
import 'package:flutter/material.dart';
import 'import_inventory_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

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
                  backgroundColor: const Color(0x2214B8A6),
                  child: Icon(icon, color: const Color(0xFF14B8A6)),
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
subtitle: 'Import your cleaned .xlsx inventory file into Firestore.',
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