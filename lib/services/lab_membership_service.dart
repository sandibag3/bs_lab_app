import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab_membership_model.dart';

class LabMembershipService {
  final CollectionReference<Map<String, dynamic>> _membershipsRef =
      FirebaseFirestore.instance.collection('memberships');

  String _membershipDocId({
    required String userId,
    required String labId,
  }) {
    final safeLabId = labId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final safeUserId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${safeLabId}_$safeUserId';
  }

  Future<void> upsertMembership({
    required String userId,
    required String labId,
    required String role,
    String status = 'active',
  }) async {
    final cleanUserId = userId.trim();
    final cleanLabId = labId.trim();

    if (cleanUserId.isEmpty || cleanLabId.isEmpty) {
      return;
    }

    final docRef = _membershipsRef.doc(
      _membershipDocId(userId: cleanUserId, labId: cleanLabId),
    );
    final existing = await docRef.get();

    if (existing.exists) {
      await docRef.update({
        'userId': cleanUserId,
        'labId': cleanLabId,
        'role': role.trim(),
        'status': status.trim().isEmpty ? 'active' : status.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await docRef.set({
      'userId': cleanUserId,
      'labId': cleanLabId,
      'role': role.trim(),
      'status': status.trim().isEmpty ? 'active' : status.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<LabMembershipModel?> getMembership({
    required String userId,
    required String labId,
  }) async {
    final cleanUserId = userId.trim();
    final cleanLabId = labId.trim();

    if (cleanUserId.isEmpty || cleanLabId.isEmpty) {
      return null;
    }

    final doc = await _membershipsRef
        .doc(_membershipDocId(userId: cleanUserId, labId: cleanLabId))
        .get();

    if (!doc.exists) {
      return null;
    }

    return LabMembershipModel.fromFirestore(doc);
  }
}
