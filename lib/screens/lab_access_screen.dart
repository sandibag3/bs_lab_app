import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/firestore_access_guard.dart';
import '../theme/labmate_theme.dart';
import 'create_lab_screen.dart';
import 'join_lab_screen.dart';

class LabAccessScreen extends StatelessWidget {
  final AppState appState;

  const LabAccessScreen({super.key, required this.appState});

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
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
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.subtleText,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
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

  void _openCreateLab(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateLabScreen(appState: appState)),
    );
  }

  void _openJoinLab(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JoinLabScreen(appState: appState)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Labmate')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.panel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a lab context',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      FirestoreAccessGuard.userMessage,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildOptionCard(
                context: context,
                icon: Icons.add_business_rounded,
                title: 'Create Lab',
                subtitle:
                    'Create a basic lab workspace and start using lab-scoped data safely.',
                onTap: () => _openCreateLab(context),
              ),
              _buildOptionCard(
                context: context,
                icon: Icons.group_add_rounded,
                title: 'Join Lab',
                subtitle:
                    'Enter a shared lab code or a mock identifier to continue with a lab context.',
                onTap: () => _openJoinLab(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
