import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab_context_model.dart';

class LabService {
  static const String _demoLabId = 'labmate-demo-lab';
  static const String _demoLabName = 'Labmate Demo Lab';
  static const String _demoLabCode = 'LAB-DEMO';
  final CollectionReference<Map<String, dynamic>> _labsRef =
      FirebaseFirestore.instance.collection('labs');

  String _normalizeIdentifier(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _buildLabCode(String docId) {
    final clean = docId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = clean.length >= 6 ? clean.substring(0, 6) : clean.padRight(6, 'X');
    return 'LAB-$suffix';
  }

  bool _matchesCleanupMarker(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    const markers = ['dummy', 'test', 'testing'];
    final compact = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (final marker in markers) {
      final boundaryPattern = RegExp(
        '(^|[^a-z0-9])${RegExp.escape(marker)}([^a-z0-9]|\$)',
      );
      if (boundaryPattern.hasMatch(normalized) || compact.startsWith(marker)) {
        return true;
      }
    }

    return false;
  }

  bool _isCleanupCandidate(
    String labId,
    Map<String, dynamic> data,
  ) {
    final cleanLabId = labId.trim();
    final labName = (data['name'] ?? '').toString().trim();
    final institute = (data['institute'] ?? '').toString().trim();
    final labCode = (data['code'] ?? '').toString().trim();

    if (cleanLabId == _demoLabId) {
      return false;
    }

    if (labName.toLowerCase() == _demoLabName.toLowerCase()) {
      return false;
    }

    if (labCode.toUpperCase() == _demoLabCode) {
      return false;
    }

    return _matchesCleanupMarker(labName) ||
        _matchesCleanupMarker(institute);
  }

  Future<Map<String, String>> createLab({
    required String labName,
    String institute = '',
    required String createdBy,
  }) async {
    final trimmedName = labName.trim();
    final trimmedInstitute = institute.trim();
    final docRef = _labsRef.doc();
    final labCode = _buildLabCode(docRef.id);

    await docRef.set({
      'name': trimmedName,
      'institute': trimmedInstitute,
      'code': labCode,
      'createdBy': createdBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'labId': docRef.id,
      'labName': trimmedName,
      'labCode': labCode,
    };
  }

  Future<LabContextModel?> findLabByIdentifier(String identifier) async {
    final rawIdentifier = identifier.trim();
    if (rawIdentifier.isEmpty) return null;

    final normalizedIdentifier = _normalizeIdentifier(rawIdentifier);

    final codeMatch = await _labsRef
        .where('code', isEqualTo: normalizedIdentifier)
        .limit(1)
        .get();

    if (codeMatch.docs.isNotEmpty) {
      final doc = codeMatch.docs.first;
      final data = doc.data();
      final name = (data['name'] ?? rawIdentifier).toString().trim();

      return LabContextModel(
        selectedLabId: doc.id,
        selectedLabName: name.isEmpty ? rawIdentifier : name,
      );
    }

    final directDoc = await _labsRef.doc(rawIdentifier).get();
    if (!directDoc.exists) {
      return null;
    }

    final data = directDoc.data() ?? {};
    final name = (data['name'] ?? rawIdentifier).toString().trim();

    return LabContextModel(
      selectedLabId: directDoc.id,
      selectedLabName: name.isEmpty ? rawIdentifier : name,
    );
  }

  Future<LabContextModel?> getLabContextById(String labId) async {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return null;
    }

    final doc = await _labsRef.doc(cleanLabId).get();
    if (!doc.exists) {
      return null;
    }

    final data = doc.data() ?? {};
    final name = (data['name'] ?? cleanLabId).toString().trim();

    return LabContextModel(
      selectedLabId: doc.id,
      selectedLabName: name.isEmpty ? cleanLabId : name,
    );
  }

  Future<Map<String, String>> getLabDetails(String labId) async {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return {};
    }

    final doc = await _labsRef.doc(cleanLabId).get();
    if (!doc.exists) {
      return {};
    }

    final data = doc.data() ?? {};
    final name = (data['name'] ?? cleanLabId).toString().trim();
    final institute = (data['institute'] ?? '').toString().trim();
    final code = (data['code'] ?? '').toString().trim();

    return {
      'labId': doc.id,
      'labName': name.isEmpty ? cleanLabId : name,
      'institute': institute,
      'labCode': code.isEmpty ? _buildLabCode(doc.id) : code,
    };
  }

  Future<void> updateLabDetails({
    required String labId,
    required String labName,
    String institute = '',
  }) async {
    final cleanLabId = labId.trim();
    final cleanLabName = labName.trim();
    final cleanInstitute = institute.trim();

    if (cleanLabId.isEmpty || cleanLabName.isEmpty) {
      return;
    }

    final docRef = _labsRef.doc(cleanLabId);
    final existing = await docRef.get();
    if (!existing.exists) {
      throw StateError('Lab not found.');
    }

    await docRef.update({
      'name': cleanLabName,
      'institute': cleanInstitute,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, String>>> getDummyTestLabCandidates() async {
    final snapshot = await _labsRef.get();

    final candidates = snapshot.docs
        .where((doc) => _isCleanupCandidate(doc.id, doc.data()))
        .map((doc) {
          final data = doc.data();
          final labName = (data['name'] ?? doc.id).toString().trim();
          final institute = (data['institute'] ?? '').toString().trim();
          final labCode = (data['code'] ?? '').toString().trim();

          return {
            'labId': doc.id,
            'labName': labName.isEmpty ? doc.id : labName,
            'institute': institute,
            'labCode': labCode,
          };
        })
        .toList();

    candidates.sort((a, b) {
      final left = (a['labName'] ?? '').toLowerCase();
      final right = (b['labName'] ?? '').toLowerCase();
      return left.compareTo(right);
    });

    return candidates;
  }

  Future<int> deleteLabsByIds(List<String> labIds) async {
    final cleanedLabIds = labIds
        .map((labId) => labId.trim())
        .where((labId) => labId.isNotEmpty && labId != _demoLabId)
        .toSet()
        .toList();

    if (cleanedLabIds.isEmpty) {
      return 0;
    }

    var deletedCount = 0;

    for (var index = 0; index < cleanedLabIds.length; index += 400) {
      final batch = FirebaseFirestore.instance.batch();
      final slice = cleanedLabIds.skip(index).take(400);

      for (final labId in slice) {
        batch.delete(_labsRef.doc(labId));
        deletedCount += 1;
      }

      await batch.commit();
    }

    return deletedCount;
  }

  LabContextModel buildLocalLabContext(String identifier) {
    final trimmedIdentifier = identifier.trim();
    final normalizedIdentifier = trimmedIdentifier
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    final localId = normalizedIdentifier.isEmpty ? 'local-lab' : 'local-$normalizedIdentifier';

    return LabContextModel(
      selectedLabId: localId,
      selectedLabName:
          trimmedIdentifier.isEmpty ? 'Local Lab' : trimmedIdentifier,
    );
  }
}
