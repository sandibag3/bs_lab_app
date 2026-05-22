import 'package:flutter/material.dart';
import '../models/chemical_model.dart';
import '../theme/labmate_theme.dart';

class ChemicalDetailScreenGroup extends StatelessWidget {
  final List<ChemicalModel> bottles;

  const ChemicalDetailScreenGroup({super.key, required this.bottles});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(bottles.first.chemicalName)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bottles.length,
        itemBuilder: (context, index) {
          final b = bottles[index];

          return Card(
            color: palette.panel,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                'Bottle ${index + 1}',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                'Qty: ${b.quantity} | ${b.location}',
                style: TextStyle(color: palette.mutedText),
              ),
              trailing: DropdownButton<String>(
                value: b.availability,
                dropdownColor: palette.panel,
                items: ['Available', 'Low', 'Finished']
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  // later we update firestore
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
