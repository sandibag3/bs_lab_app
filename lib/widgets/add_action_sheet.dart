import 'package:flutter/material.dart';
import '../theme/labmate_theme.dart';

class AddActionSheet extends StatelessWidget {
  final VoidCallback onAddRequirement;
  final VoidCallback onAddNewChemical;
  final VoidCallback onAddEvent;

  const AddActionSheet({
    super.key,
    required this.onAddRequirement,
    required this.onAddNewChemical,
    required this.onAddEvent,
  });

  Widget buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

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
                  radius: 22,
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: palette.subtleText,
                  size: 16,
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
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            buildOption(
              context: context,
              icon: Icons.playlist_add_check_rounded,
              title: 'Requirement',
              subtitle: 'Add a new chemical or consumable requirement.',
              onTap: onAddRequirement,
            ),
            buildOption(
              context: context,
              icon: Icons.science_rounded,
              title: 'New Chemical',
              subtitle: 'Inventory in-charge can add delivered chemicals.',
              onTap: onAddNewChemical,
            ),
            buildOption(
              context: context,
              icon: Icons.event_available_rounded,
              title: 'Event',
              subtitle: 'Add a new upcoming lab event.',
              onTap: onAddEvent,
            ),
          ],
        ),
      ),
    );
  }
}
