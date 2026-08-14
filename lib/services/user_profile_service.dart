import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserProfileService {
  final CollectionReference<Map<String, dynamic>> _usersRef = FirebaseFirestore
      .instance
      .collection('users');

  Future<UserProfile> getOrCreateUserProfile({
    required String userId,
    required String email,
    DateTime? accountCreatedAt,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return UserProfile.empty();
    }

    final docRef = _usersRef.doc(cleanUserId);
    final doc = await docRef.get();

    if (!doc.exists) {
      final firstLoginAt = accountCreatedAt ?? DateTime.now();
      final profile = UserProfile.empty().copyWith(
        firstLoginAt: firstLoginAt,
        clearDesignation: true,
        clearResearchArea: true,
        showEmailToLabMembers: true,
        showMobileToLabMembers: false,
        profileCompleted: false,
      );

      await docRef.set({
        ...profile.toFirestore(),
        'email': email.trim(),
        'firstLoginAt': Timestamp.fromDate(firstLoginAt),
        'designation': null,
        'researchArea': null,
        'showEmailToLabMembers': true,
        'showMobileToLabMembers': false,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return profile;
    }

    final profile = UserProfile.fromFirestore(doc);
    if (profile.firstLoginAt == null) {
      final firstLoginAt = accountCreatedAt ?? DateTime.now();
      await docRef.set({
        'email': email.trim(),
        'firstLoginAt': Timestamp.fromDate(firstLoginAt),
      }, SetOptions(merge: true));

      return profile.copyWith(firstLoginAt: firstLoginAt);
    }

    return profile;
  }

  Future<void> saveUserProfile({
    required String userId,
    required String email,
    required UserProfile profile,
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return;
    }

    await _usersRef.doc(cleanUserId).set({
      ...profile.toFirestore(),
      'email': email.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> completeBasicProfile({
    required String uid,
    required String name,
    required String contactNumber,
    required String dateOfBirth,
    String? designation,
    String? researchArea,
    required bool showEmailToLabMembers,
    required bool showMobileToLabMembers,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      return;
    }

    await _usersRef.doc(cleanUid).set({
      'name': name.trim(),
      'contactNumber': contactNumber.trim(),
      'dateOfBirth': dateOfBirth.trim(),
      'designation': _nullableTrimmedString(designation),
      'researchArea': _nullableTrimmedString(researchArea),
      'showEmailToLabMembers': showEmailToLabMembers,
      'showMobileToLabMembers': showMobileToLabMembers,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, UserProfile>> getUserProfilesByIds(
    Iterable<String> userIds,
  ) async {
    const chunkSize = 10;
    final cleanUserIds = userIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList();
    final profiles = <String, UserProfile>{};

    for (var index = 0; index < cleanUserIds.length; index += chunkSize) {
      final end = index + chunkSize > cleanUserIds.length
          ? cleanUserIds.length
          : index + chunkSize;
      final chunk = cleanUserIds.sublist(index, end);
      final snapshot = await _usersRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        profiles[doc.id] = UserProfile.fromFirestore(doc);
      }
    }

    return profiles;
  }

  String? _nullableTrimmedString(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isEmpty ? null : cleanValue;
  }
}
