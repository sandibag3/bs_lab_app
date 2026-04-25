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
      final profile = UserProfile.empty().copyWith(firstLoginAt: firstLoginAt);

      await docRef.set({
        ...profile.toFirestore(),
        'email': email.trim(),
        'firstLoginAt': Timestamp.fromDate(firstLoginAt),
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
}
