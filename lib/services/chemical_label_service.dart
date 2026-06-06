import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    try {
      final cleanLabel = label.trim();
      final cleanPrefix = prefix.trim();
      if (cleanLabel.isEmpty || cleanPrefix.isEmpty) return null;

      final match = RegExp(
        '^${RegExp.escape(cleanPrefix)}-(\\d+)\$',
        caseSensitive: false,
      ).firstMatch(cleanLabel);

      if (match == null) return null;
      return int.tryParse(match.group(1) ?? '');
    } catch (_) {
      return null;
    }
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
        .get();

    final serials = <int>{};
    for (final doc in query.docs) {
      final label = (doc.data()['label'] ?? '').toString();
      final serial = parseLabelSerial(label: label, prefix: cleanPrefix);
      if (serial != null && serial > 0) {
        serials.add(serial);
      }
    }

    final sortedSerials = serials.toList()..sort();
    debugPrint(
      'ChemicalLabelService: prefix=$cleanPrefix valid serials found=$sortedSerials',
    );

    if (serials.isEmpty) return [];

    final maxSerial = sortedSerials.last;
    final missingLabels = <String>[];
    for (var serial = 1; serial < maxSerial; serial++) {
      if (!serials.contains(serial)) {
        missingLabels.add('$cleanPrefix-$serial');
      }
    }

    debugPrint(
      'ChemicalLabelService: prefix=$cleanPrefix missing serials found=$missingLabels',
    );
    return missingLabels;
  }

  Future<String> suggestNextLabelForPrefix({
    required String labId,
    required String prefix,
  }) async {
    final cleanPrefix = prefix.trim();
    if (cleanPrefix.isEmpty) return 'UNK-1';

    List<String> missingLabels = const [];
    try {
      missingLabels = await findMissingLabelsForPrefix(
        labId: labId,
        prefix: cleanPrefix,
      );
    } catch (error) {
      debugPrint(
        'ChemicalLabelService: missing-label detection failed for $cleanPrefix, falling back. $error',
      );
    }

    if (missingLabels.isNotEmpty) {
      debugPrint(
        'ChemicalLabelService: prefix=$cleanPrefix chosen label=${missingLabels.first}',
      );
      return missingLabels.first;
    }

    try {
      final labelData = await generateLabel(prefix: cleanPrefix);
      final label = (labelData['label'] ?? '').toString().trim();
      final chosenLabel = label.isEmpty ? '$cleanPrefix-1' : label;
      debugPrint(
        'ChemicalLabelService: prefix=$cleanPrefix chosen label=$chosenLabel',
      );
      return chosenLabel;
    } catch (error) {
      debugPrint(
        'ChemicalLabelService: generateLabel fallback failed for $cleanPrefix. $error',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> generateLabel({
    required String prefix,
  }) async {
    final cleanPrefix = prefix.trim();
    if (cleanPrefix.isEmpty) {
      return {
        'prefix': cleanPrefix,
        'serialNumber': 1,
        'label': 'UNK-1',
      };
    }

    final query = await _firestore
        .collection('inventory') // fixed from chemicals -> inventory
        .where('label', isGreaterThanOrEqualTo: '$cleanPrefix-')
        .where('label', isLessThan: '$cleanPrefix-\uf8ff')
        .get();

    int nextNumber = 1;

    for (final doc in query.docs) {
      final data = doc.data();
      if (!_matchesCurrentLab(data)) continue;
      final label = (data['label'] ?? '').toString().trim();

      final number = parseLabelSerial(label: label, prefix: cleanPrefix);
      if (number != null && number >= nextNumber) {
        nextNumber = number + 1;
      }
    }

    return {
      'prefix': cleanPrefix,
      'serialNumber': nextNumber,
      'label': '$cleanPrefix-$nextNumber',
    };
  }
}
