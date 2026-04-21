import 'package:flutter/material.dart';
import '../app_state.dart';
import 'create_lab_screen.dart';
import 'home_screen.dart';
import 'join_lab_screen.dart';

class LabAccessScreen extends StatelessWidget {
  final AppState appState;

  const LabAccessScreen({
    super.key,
    required this.appState,
  });

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFF1E293B),
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
                  child: Icon(
                    icon,
                    color: const Color(0xFF14B8A6),
                  ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.4,
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

  Widget _buildRoleSelector() {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final selectedRole = appState.demoUserRole;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demo Role',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This role is stored locally on this device for now.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: DemoUserRole.values.map((role) {
                return ChoiceChip(
                  label: Text(role.label),
                  selected: selectedRole == role,
                  selectedColor: const Color(0xFF14B8A6),
                  backgroundColor: const Color(0xFF1E293B),
                  labelStyle: TextStyle(
                    color: selectedRole == role ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) async {
                    await appState.saveDemoRole(role);
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  void _openCreateLab(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLabScreen(appState: appState),
      ),
    );
  }

  void _openJoinLab(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JoinLabScreen(appState: appState),
      ),
    );
  }

  Future<void> _openDemoMode(BuildContext context) async {
    await appState.enterDemoLab();
    await appState.saveDemoRole(appState.demoUserRole);
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(appState: appState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Labmate',
          style: TextStyle(color: Colors.white),
        ),
      ),
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
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a lab context',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create a new lab, join an existing lab, or continue into Demo Mode with a default demo lab context.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildOptionCard(
                icon: Icons.add_business_rounded,
                title: 'Create Lab',
                subtitle:
                    'Create a basic lab workspace and start using lab-scoped data safely.',
                onTap: () => _openCreateLab(context),
              ),
              _buildOptionCard(
                icon: Icons.group_add_rounded,
                title: 'Join Lab',
                subtitle:
                    'Enter a shared lab code or a mock identifier to continue with a lab context.',
                onTap: () => _openJoinLab(context),
              ),
              const SizedBox(height: 6),
              _buildRoleSelector(),
              const SizedBox(height: 20),
              _buildOptionCard(
                icon: Icons.science_rounded,
                title: 'Demo Mode',
                subtitle:
                    'Continue into the current dashboard using the selected role inside the Labmate Demo Lab.',
                onTap: () async => _openDemoMode(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
