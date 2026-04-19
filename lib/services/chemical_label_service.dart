import 'package:cloud_firestore/cloud_firestore.dart';

class ChemicalLabelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getPrefix({
    required String category,
    String? subcategory,
    int? carbonCount,
    String? catalystMetal,
  }) {
    final c = category.trim().toLowerCase();
    final s = subcategory?.trim().toLowerCase();

    if (c == 'acid') return 'A';

    if (c == 'base') {
      if (s == 'organic') return 'OB';
      if (s == 'inorganic') return 'IB';
      return 'B';
    }

    if (c == 'salt') return 'S';

    if (c == 'metal') return 'M';

    if (c == 'catalyst') {
      if (catalystMetal != null && catalystMetal.trim().isNotEmpty) {
        return _normalizeMetalPrefix(catalystMetal);
      }
      return 'CAT';
    }

    if (c == 'ligand') {
      if (s == 'phosphine') return 'Phos';
      if (s == 'n-donor' || s == 'nitrogen donor') return 'ND';
      return 'L';
    }

    if (c == 'general') {
      if (carbonCount != null && carbonCount > 0) {
        return 'C$carbonCount';
      }
      return 'C';
    }

    return 'UNK';
  }

  String _normalizeMetalPrefix(String metal) {
    final value = metal.trim();
    if (value.isEmpty) return 'CAT';

    if (value.length == 1) {
      return value.toUpperCase();
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<Map<String, dynamic>> generateLabel({
    required String prefix,
  }) async {
    final query = await _firestore
        .collection('inventory') // fixed from chemicals -> inventory
        .where('label', isGreaterThanOrEqualTo: '$prefix-')
        .where('label', isLessThan: '$prefix-\uf8ff')
        .get();

    int nextNumber = 1;

    for (final doc in query.docs) {
      final data = doc.data();
      final label = (data['label'] ?? '').toString().trim();

      final match = RegExp('^${RegExp.escape(prefix)}-(\\d+)\$').firstMatch(label);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (number >= nextNumber) {
          nextNumber = number + 1;
        }
      }
    }

    return {
      'prefix': prefix,
      'serialNumber': nextNumber,
      'label': '$prefix-$nextNumber',
    };
  }
}