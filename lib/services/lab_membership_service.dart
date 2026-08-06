import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lab_membership_model.dart';

class LabMembershipException implements Exception {
  final String message;

  const LabMembershipException(this.message);

  @override
  String toString() => message;
}

class LabRoleMigrationResult {
  final String piUid;
  final String resolutionSource;
  final bool migrationAttempted;
  final bool migrationSucceeded;
  final bool assignmentRequired;
  final String assignmentReason;

  const LabRoleMigrationResult({
    required this.piUid,
    required this.resolutionSource,
    required this.migrationAttempted,
    required this.migrationSucceeded,
    required this.assignmentRequired,
    required this.assignmentReason,
  });

  const LabRoleMigrationResult.none({
    this.assignmentRequired = false,
    this.assignmentReason = '',
  }) : piUid = '',
       resolutionSource = '',
       migrationAttempted = false,
       migrationSucceeded = false;
}

class _PiCandidate {
  final String uid;
  final String source;

  const _PiCandidate({required this.uid, required this.source});
}

class LabMembershipService {
  final CollectionReference<Map<String, dynamic>> _membershipsRef =
      FirebaseFirestore.instance.collection('memberships');
  final CollectionReference<Map<String, dynamic>> _labsRef = FirebaseFirestore
      .instance
      .collection('labs');
  final CollectionReference<Map<String, dynamic>> _usersRef = FirebaseFirestore
      .instance
      .collection('users');

  static String membershipIdFor({
    required String userId,
    required String labId,
  }) {
    final safeLabId = labId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final safeUserId = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '${safeLabId}_$safeUserId';
  }

  String _membershipDocId({required String userId, required String labId}) {
    return membershipIdFor(userId: userId, labId: labId);
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

  static String normalizeAccessRole(String role, {bool isPi = false}) {
    final normalized = role.trim().toLowerCase();
    if (isPi || normalized == 'pi') {
      return 'pi';
    }

    if (normalized == 'admin' || normalized == 'piadmin') {
      return 'admin';
    }

    return 'member';
  }

  static bool isLegacyPiAdminRole(String role) {
    return role.trim().toLowerCase() == 'piadmin';
  }

  static bool isPiRole(String role) {
    return role.trim().toLowerCase() == 'pi';
  }

  static bool isAdminRole(String role) {
    return role.trim().toLowerCase() == 'admin';
  }

  static bool isMemberRole(String role) {
    return role.trim().toLowerCase() == 'member';
  }

  String? _normalizedUidField(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  _PiCandidate _trustedPiCandidateFrom(Map<String, dynamic> labData) {
    final piUid = _normalizedUidField(labData['piUid']);
    if (piUid != null) {
      return _PiCandidate(uid: piUid, source: 'piUid');
    }

    const trustedLegacyUidFields = [
      'principalInvestigatorUid',
      'principalInvestigatorId',
      'ownerUid',
      'ownerId',
      'createdByUid',
    ];

    for (final field in trustedLegacyUidFields) {
      final uid = _normalizedUidField(labData[field]);
      if (uid != null) {
        return _PiCandidate(uid: uid, source: field);
      }
    }

    return const _PiCandidate(uid: '', source: '');
  }

  Future<_PiCandidate> _profilePiCandidateFromLegacyPiAdmins(
    List<LabMembershipModel> memberships,
  ) async {
    final legacyPiAdminMemberships = memberships
        .where((membership) {
          return isLegacyPiAdminRole(membership.role);
        })
        .toList(growable: false);

    if (legacyPiAdminMemberships.isEmpty) {
      return const _PiCandidate(uid: '', source: '');
    }

    final profilePiUserIds = <String>[];
    for (final membership in legacyPiAdminMemberships) {
      final userId = membership.userId.trim();
      if (userId.isEmpty) {
        continue;
      }

      final DocumentSnapshot<Map<String, dynamic>> profileDoc;
      try {
        profileDoc = await _usersRef.doc(userId).get();
      } catch (_) {
        continue;
      }

      final profileRole = profileDoc.data()?['joinAs']?.toString().trim() ?? '';
      if (profileRole.toLowerCase() == 'pi') {
        profilePiUserIds.add(userId);
      }
    }

    if (profilePiUserIds.length == 1) {
      return _PiCandidate(
        uid: profilePiUserIds.single,
        source: 'singleProfilePiLegacyPiAdmin',
      );
    }

    if (profilePiUserIds.length > 1) {
      return const _PiCandidate(
        uid: '',
        source: 'multipleProfilePiLegacyPiAdmins',
      );
    }

    return const _PiCandidate(uid: '', source: '');
  }

  Future<LabRoleMigrationResult> migrateLabAccessRolesIfNeeded({
    required String labId,
    required String currentUserId,
  }) async {
    final cleanLabId = labId.trim();
    final cleanCurrentUserId = currentUserId.trim();
    if (cleanLabId.isEmpty || cleanCurrentUserId.isEmpty) {
      return const LabRoleMigrationResult.none();
    }

    final labRef = _labsRef.doc(cleanLabId);
    final labSnapshot = await labRef.get();
    if (!labSnapshot.exists) {
      return const LabRoleMigrationResult.none(
        assignmentRequired: true,
        assignmentReason: 'Lab document was not found.',
      );
    }

    final memberships = await getMembershipsForLab(labId: cleanLabId);
    final labData = labSnapshot.data() ?? {};
    var candidate = _trustedPiCandidateFrom(labData);

    if (candidate.uid.isEmpty) {
      candidate = await _profilePiCandidateFromLegacyPiAdmins(memberships);
    }

    if (candidate.source == 'multipleProfilePiLegacyPiAdmins') {
      return const LabRoleMigrationResult.none(
        assignmentRequired: true,
        assignmentReason:
            'Multiple legacy PI candidates were found. PI assignment must be resolved in the app.',
      );
    }

    if (candidate.uid.isEmpty) {
      return const LabRoleMigrationResult.none(
        assignmentRequired: true,
        assignmentReason:
            'No trusted PI ownership field or single legacy PI profile was found.',
      );
    }

    final shouldAttemptMigration = candidate.uid == cleanCurrentUserId;
    var migrationSucceeded = false;
    if (shouldAttemptMigration) {
      migrationSucceeded = await _applyPrincipalInvestigatorRoleTransaction(
        labId: cleanLabId,
        newPiUserId: candidate.uid,
        memberships: memberships,
        requireCurrentPiUserId: '',
        allowMissingPiUid: true,
      );
    }

    return LabRoleMigrationResult(
      piUid: candidate.uid,
      resolutionSource: migrationSucceeded ? 'piUid' : candidate.source,
      migrationAttempted: shouldAttemptMigration,
      migrationSucceeded: migrationSucceeded,
      assignmentRequired: false,
      assignmentReason: '',
    );
  }

  Future<bool> _applyPrincipalInvestigatorRoleTransaction({
    required String labId,
    required String newPiUserId,
    required List<LabMembershipModel> memberships,
    required String requireCurrentPiUserId,
    required bool allowMissingPiUid,
  }) async {
    final cleanLabId = labId.trim();
    final cleanNewPiUserId = newPiUserId.trim();
    final cleanRequiredPiUserId = requireCurrentPiUserId.trim();
    if (cleanLabId.isEmpty || cleanNewPiUserId.isEmpty) {
      return false;
    }

    final labRef = _labsRef.doc(cleanLabId);
    final membershipRefs = {
      for (final membership in memberships)
        if (membership.userId.trim().isNotEmpty)
          membership.userId.trim(): _membershipsRef.doc(
            _membershipDocId(
              userId: membership.userId.trim(),
              labId: cleanLabId,
            ),
          ),
    };

    if (!membershipRefs.containsKey(cleanNewPiUserId)) {
      membershipRefs[cleanNewPiUserId] = _membershipsRef.doc(
        _membershipDocId(userId: cleanNewPiUserId, labId: cleanLabId),
      );
    }

    return FirebaseFirestore.instance.runTransaction<bool>((transaction) async {
      final labSnapshot = await transaction.get(labRef);
      if (!labSnapshot.exists) {
        throw const LabMembershipException('Lab document was not found.');
      }

      final labData = labSnapshot.data() ?? {};
      final existingPiUid = _normalizedUidField(labData['piUid']);
      if (cleanRequiredPiUserId.isNotEmpty &&
          existingPiUid != cleanRequiredPiUserId) {
        throw const LabMembershipException(
          'Only the current PI can transfer PI ownership.',
        );
      }

      if (!allowMissingPiUid &&
          existingPiUid != null &&
          existingPiUid != cleanRequiredPiUserId) {
        throw const LabMembershipException(
          'Only the current PI can transfer PI ownership.',
        );
      }

      if (allowMissingPiUid && existingPiUid == null) {
        final trustedCandidate = _trustedPiCandidateFrom(labData);
        if (trustedCandidate.uid.isNotEmpty &&
            trustedCandidate.uid != cleanNewPiUserId) {
          throw const LabMembershipException(
            'PI ownership could not be verified.',
          );
        }
      }

      final membershipSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in membershipRefs.entries) {
        membershipSnapshots[entry.key] = await transaction.get(entry.value);
      }

      final newPiSnapshot = membershipSnapshots[cleanNewPiUserId];
      if (newPiSnapshot == null || !newPiSnapshot.exists) {
        throw const LabMembershipException(
          'Selected PI membership was not found.',
        );
      }

      final newPiMembership = LabMembershipModel.fromFirestore(newPiSnapshot);
      final newPiStatus = newPiMembership.status.trim().toLowerCase();
      if (newPiMembership.labId.trim() != cleanLabId ||
          (newPiStatus.isNotEmpty && newPiStatus != 'active')) {
        throw const LabMembershipException(
          'Selected PI membership is not active.',
        );
      }

      transaction.update(labRef, {'piUid': cleanNewPiUserId});

      for (final entry in membershipRefs.entries) {
        final snapshot = membershipSnapshots[entry.key];
        if (snapshot == null || !snapshot.exists) {
          continue;
        }

        final membership = LabMembershipModel.fromFirestore(snapshot);
        if (membership.labId.trim() != cleanLabId) {
          continue;
        }

        final status = membership.status.trim().toLowerCase();
        if (status.isNotEmpty && status != 'active') {
          continue;
        }

        final nextRole = membership.userId.trim() == cleanNewPiUserId
            ? 'pi'
            : normalizeAccessRole(membership.role);
        final currentRole = membership.role.trim();
        if (currentRole != nextRole) {
          transaction.update(snapshot.reference, {
            'role': nextRole,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return true;
    });
  }

  Future<void> transferPrincipalInvestigator({
    required String labId,
    required String newPiUserId,
    required String currentPiUserId,
  }) async {
    final cleanLabId = labId.trim();
    final cleanNewPiUserId = newPiUserId.trim();
    final cleanCurrentPiUserId = currentPiUserId.trim();
    if (cleanLabId.isEmpty ||
        cleanNewPiUserId.isEmpty ||
        cleanCurrentPiUserId.isEmpty) {
      throw const LabMembershipException('PI transfer could not be verified.');
    }

    final memberships = await getMembershipsForLab(labId: cleanLabId);
    final succeeded = await _applyPrincipalInvestigatorRoleTransaction(
      labId: cleanLabId,
      newPiUserId: cleanNewPiUserId,
      memberships: memberships,
      requireCurrentPiUserId: cleanCurrentPiUserId,
      allowMissingPiUid: false,
    );

    if (!succeeded) {
      throw const LabMembershipException('PI transfer could not be completed.');
    }
  }

  Future<void> claimPrincipalInvestigatorFromLegacyProfile({
    required String labId,
    required String currentUserId,
  }) async {
    final cleanLabId = labId.trim();
    final cleanCurrentUserId = currentUserId.trim();
    if (cleanLabId.isEmpty || cleanCurrentUserId.isEmpty) {
      throw const LabMembershipException(
        'PI assignment could not be verified.',
      );
    }

    final membership = await getMembership(
      userId: cleanCurrentUserId,
      labId: cleanLabId,
    );
    if (membership == null || !isLegacyPiAdminRole(membership.role)) {
      throw const LabMembershipException(
        'Only a legacy PI-profile admin can confirm PI ownership.',
      );
    }

    final profileDoc = await _usersRef.doc(cleanCurrentUserId).get();
    final profileRole = profileDoc.data()?['joinAs']?.toString().trim() ?? '';
    if (profileRole.toLowerCase() != 'pi') {
      throw const LabMembershipException(
        'Only a member whose Profile Role is PI can confirm PI ownership.',
      );
    }

    final labSnapshot = await _labsRef.doc(cleanLabId).get();
    final existingPiUid = _normalizedUidField(labSnapshot.data()?['piUid']);
    if (existingPiUid != null && existingPiUid != cleanCurrentUserId) {
      throw const LabMembershipException(
        'This lab already has a different PI assigned.',
      );
    }

    final memberships = await getMembershipsForLab(labId: cleanLabId);
    final succeeded = await _applyPrincipalInvestigatorRoleTransaction(
      labId: cleanLabId,
      newPiUserId: cleanCurrentUserId,
      memberships: memberships,
      requireCurrentPiUserId: '',
      allowMissingPiUid: true,
    );

    if (!succeeded) {
      throw const LabMembershipException(
        'PI assignment could not be completed.',
      );
    }
  }

  Future<bool> labHasActivePiOrLegacyAdmin({
    required String labId,
    String excludingUserId = '',
  }) async {
    final cleanLabId = labId.trim();
    final cleanExcludingUserId = excludingUserId.trim();
    if (cleanLabId.isEmpty) {
      return false;
    }

    final snapshot = await _membershipsRef
        .where('labId', isEqualTo: cleanLabId)
        .where('role', whereIn: ['pi', 'admin', 'piAdmin'])
        .get();

    return snapshot.docs.map(LabMembershipModel.fromFirestore).any((
      membership,
    ) {
      final status = membership.status.trim().toLowerCase();
      final isActive = status.isEmpty || status == 'active';
      final isDifferentUser =
          cleanExcludingUserId.isEmpty ||
          membership.userId.trim() != cleanExcludingUserId;

      return isActive && isDifferentUser;
    });
  }

  Future<void> updateMembershipRole({
    required String userId,
    required String labId,
    required String role,
    String currentUserId = '',
  }) async {
    final cleanUserId = userId.trim();
    final cleanLabId = labId.trim();
    final cleanRole = role.trim();

    if (cleanUserId.isEmpty || cleanLabId.isEmpty || cleanRole.isEmpty) {
      return;
    }

    final normalizedRole = normalizeAccessRole(cleanRole);
    if (normalizedRole == 'pi') {
      await transferPrincipalInvestigator(
        labId: cleanLabId,
        newPiUserId: cleanUserId,
        currentPiUserId: currentUserId,
      );
      return;
    }

    final membershipRef = _membershipsRef.doc(
      _membershipDocId(userId: cleanUserId, labId: cleanLabId),
    );
    final existing = await membershipRef.get();
    if (!existing.exists) {
      throw const LabMembershipException('Membership no longer exists.');
    }

    final membership = LabMembershipModel.fromFirestore(existing);
    if (isPiRole(membership.role)) {
      throw const LabMembershipException(
        'Transfer PI ownership before changing the current PI access role.',
      );
    }

    await membershipRef.update({
      'role': normalizedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveLab({required String labId, required String userId}) async {
    final cleanLabId = labId.trim();
    final cleanUserId = userId.trim();

    if (cleanLabId.isEmpty || cleanUserId.isEmpty) {
      throw const LabMembershipException('Membership no longer exists.');
    }

    final membershipRef = _membershipsRef.doc(
      _membershipDocId(userId: cleanUserId, labId: cleanLabId),
    );

    final initialSnapshot = await membershipRef.get();
    if (!initialSnapshot.exists) {
      throw const LabMembershipException('Membership no longer exists.');
    }

    final initialMembership = LabMembershipModel.fromFirestore(initialSnapshot);
    _validateMembershipOwner(
      membership: initialMembership,
      labId: cleanLabId,
      userId: cleanUserId,
    );

    final initialStatus = initialMembership.status.trim().toLowerCase();
    if (initialStatus == 'left') {
      throw const LabMembershipException('You have already left this lab.');
    }

    final isPi = isPiRole(initialMembership.role);
    if (isPi) {
      throw const LabMembershipException(
        'Transfer PI ownership before leaving this lab.',
      );
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(membershipRef);
      if (!snapshot.exists) {
        throw const LabMembershipException('Membership no longer exists.');
      }

      final membership = LabMembershipModel.fromFirestore(snapshot);
      _validateMembershipOwner(
        membership: membership,
        labId: cleanLabId,
        userId: cleanUserId,
      );

      final status = membership.status.trim().toLowerCase();
      if (status == 'left') {
        throw const LabMembershipException('You have already left this lab.');
      }

      final role = membership.role.trim().toLowerCase();
      if (role == 'pi') {
        throw const LabMembershipException(
          'Transfer PI ownership before leaving this lab.',
        );
      }

      transaction.update(membershipRef, {
        'status': 'left',
        'leftAt': FieldValue.serverTimestamp(),
        'leftBy': cleanUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<int> deleteMembershipsForLabs(List<String> labIds) async {
    final cleanedLabIds = labIds
        .map((labId) => labId.trim())
        .where((labId) => labId.isNotEmpty)
        .toSet()
        .toList();

    if (cleanedLabIds.isEmpty) {
      return 0;
    }

    var deletedCount = 0;

    for (var index = 0; index < cleanedLabIds.length; index += 10) {
      final chunk = cleanedLabIds.skip(index).take(10).toList();
      final snapshot = await _membershipsRef
          .where('labId', whereIn: chunk)
          .get();

      if (snapshot.docs.isEmpty) {
        continue;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      deletedCount += snapshot.docs.length;
      await batch.commit();
    }

    return deletedCount;
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

  void _validateMembershipOwner({
    required LabMembershipModel membership,
    required String labId,
    required String userId,
  }) {
    if (membership.labId.trim() != labId ||
        membership.userId.trim() != userId) {
      throw const LabMembershipException('Membership no longer exists.');
    }
  }
}
