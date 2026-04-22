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
    String userName = '',
    String userEmail = '',
    String labName = '',
  }) async {
    final cleanUserId = userId.trim();
    final cleanLabId = labId.trim();
    final cleanRole = role.trim();
    final cleanStatus = status.trim().isEmpty ? 'active' : status.trim();
    final cleanUserName = userName.trim();
    final cleanUserEmail = userEmail.trim();
    final cleanLabName = labName.trim();

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
        'role': cleanRole,
        'status': cleanStatus,
        'userName': cleanUserName,
        'userEmail': cleanUserEmail,
        'labName': cleanLabName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await docRef.set({
      'userId': cleanUserId,
      'labId': cleanLabId,
      'role': cleanRole,
      'status': cleanStatus,
      'userName': cleanUserName,
      'userEmail': cleanUserEmail,
      'labName': cleanLabName,
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

  Future<List<LabMembershipModel>> getMembershipsForUser({
    required String userId,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return [];
    }

    final snapshot = await _membershipsRef
        .where('userId', isEqualTo: cleanUserId)
        .get();

    final memberships = snapshot.docs
        .map(LabMembershipModel.fromFirestore)
        .where((membership) {
          final status = membership.status.trim().toLowerCase();
          return status.isEmpty || status == 'active';
        })
        .toList();

    memberships.sort((a, b) {
      final left = a.labName.trim().toLowerCase();
      final right = b.labName.trim().toLowerCase();
      return left.compareTo(right);
    });

    return memberships;
  }

  Future<List<LabMembershipModel>> getMembershipsForLab({
    required String labId,
  }) async {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return [];
    }

    final snapshot = await _membershipsRef
        .where('labId', isEqualTo: cleanLabId)
        .get();

    final memberships = snapshot.docs
        .map(LabMembershipModel.fromFirestore)
        .where((membership) {
          final status = membership.status.trim().toLowerCase();
          return status.isEmpty || status == 'active';
        })
        .toList();

    memberships.sort((a, b) {
      final left = _memberDisplayName(a).toLowerCase();
      final right = _memberDisplayName(b).toLowerCase();
      return left.compareTo(right);
    });

    return memberships;
  }

  String _memberDisplayName(LabMembershipModel membership) {
    final userName = membership.userName.trim();
    if (userName.isNotEmpty) {
      return userName;
    }

    final userEmail = membership.userEmail.trim();
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    return membership.userId.trim();
  }
}
