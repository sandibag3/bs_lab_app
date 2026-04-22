import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab_context_model.dart';

class LabService {
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
