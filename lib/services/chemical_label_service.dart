import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';

class ChemicalLabelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

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

  int? parseLabelSerial({
    required String label,
    required String prefix,
  }) {
    final cleanLabel = label.trim();
    final cleanPrefix = prefix.trim();
    if (cleanLabel.isEmpty || cleanPrefix.isEmpty) return null;

    final match = RegExp(
      '^${RegExp.escape(cleanPrefix)}-(\\d+)\$',
      caseSensitive: false,
    ).firstMatch(cleanLabel);

    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  Future<List<String>> findMissingLabelsForPrefix({
    required String labId,
    required String prefix,
  }) async {
    final cleanLabId = labId.trim();
    final cleanPrefix = prefix.trim();
    if (cleanLabId.isEmpty || cleanPrefix.isEmpty) return [];

    final query = await _firestore
        .collection('inventory')
        .where('labId', isEqualTo: cleanLabId)
        .where('label', isGreaterThanOrEqualTo: '$cleanPrefix-')
        .where('label', isLessThan: '$cleanPrefix-\uf8ff')
        .get();

    final serials = <int>{};
    for (final doc in query.docs) {
      final label = (doc.data()['label'] ?? '').toString();
      final serial = parseLabelSerial(label: label, prefix: cleanPrefix);
      if (serial != null && serial > 0) {
        serials.add(serial);
      }
    }

    if (serials.isEmpty) return [];

    final maxSerial = serials.reduce((a, b) => a > b ? a : b);
    final missingLabels = <String>[];
    for (var serial = 1; serial < maxSerial; serial++) {
      if (!serials.contains(serial)) {
        missingLabels.add('$cleanPrefix-$serial');
      }
    }

    return missingLabels;
  }

  Future<String> suggestNextLabelForPrefix({
    required String labId,
    required String prefix,
  }) async {
    final cleanPrefix = prefix.trim();
    final missingLabels = await findMissingLabelsForPrefix(
      labId: labId,
      prefix: cleanPrefix,
    );

    if (missingLabels.isNotEmpty) {
      return missingLabels.first;
    }

    final labelData = await generateLabel(prefix: cleanPrefix);
    return (labelData['label'] ?? '').toString();
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
      if (!_matchesCurrentLab(data)) continue;
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
