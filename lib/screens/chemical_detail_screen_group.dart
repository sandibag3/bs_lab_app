import 'package:flutter/material.dart';
import '../models/chemical_model.dart';

class ChemicalDetailScreenGroup extends StatelessWidget {
  final List<ChemicalModel> bottles;

  const ChemicalDetailScreenGroup({super.key, required this.bottles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(bottles.first.chemicalName)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bottles.length,
        itemBuilder: (context, index) {
          final b = bottles[index];

          return Card(
            color: const Color(0xFF1E293B),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                'Bottle ${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Qty: ${b.quantity} | ${b.location}',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: DropdownButton<String>(
                value: b.availability,
                dropdownColor: const Color(0xFF1E293B),
                items: ['Available', 'Low', 'Finished']
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e,
                              style: const TextStyle(color: Colors.white)),
                        ))
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