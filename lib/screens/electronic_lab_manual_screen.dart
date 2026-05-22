import 'package:flutter/material.dart';

import '../theme/labmate_theme.dart';

class ElectronicLabManualScreen extends StatelessWidget {
  const ElectronicLabManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    final manualSections = [
      'General Lab Safety',
      'Chemical Handling Guidelines',
      'Waste Disposal',
      'Instrument Usage SOP',
      'Emergency Contact Information',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: manualSections.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      manualSections[index],
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
