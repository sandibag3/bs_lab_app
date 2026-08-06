import 'package:firebase_auth/firebase_auth.dart';

import '../app_state.dart';
import '../models/lab_membership_model.dart';
import '../models/user_profile.dart';
import 'lab_membership_service.dart';
import 'user_profile_service.dart';

class PersonDisplayResolver {
  final UserProfileService _userProfileService;
  final LabMembershipService _labMembershipService;

  PersonDisplayResolver({
    UserProfileService? userProfileService,
    LabMembershipService? labMembershipService,
  }) : _userProfileService = userProfileService ?? UserProfileService(),
       _labMembershipService = labMembershipService ?? LabMembershipService();

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isLikelyEmail(String? value) {
    final cleanValue = value?.trim() ?? '';
    return cleanValue.isNotEmpty && _emailPattern.hasMatch(cleanValue);
  }

  static bool hasUsableDisplayName(String? value) {
    final cleanValue = value?.trim() ?? '';
    if (cleanValue.isEmpty || isLikelyEmail(cleanValue)) {
      return false;
    }

    return cleanValue.toLowerCase() != 'your name';
  }

  static String resolvePersonDisplayName({
    String? explicitDisplayName,
    UserProfile? profile,
    LabMembershipModel? membership,
    String? firebaseDisplayName,
    String? email,
    String? uid,
    String fallbackLabel = '',
  }) {
    final storedName = _usableName(explicitDisplayName);
    if (storedName != null) return storedName;

    final profileName = _usableName(profile?.name);
    if (profileName != null) return profileName;

    final membershipName = _usableName(membership?.userName);
    if (membershipName != null) return membershipName;

    final firebaseName = _usableName(firebaseDisplayName);
    if (firebaseName != null) return firebaseName;

    final explicitEmail = _usableEmail(explicitDisplayName);
    final cleanEmail =
        _usableEmail(email) ??
        explicitEmail ??
        _usableEmail(membership?.userEmail);
    if (cleanEmail != null) return cleanEmail;

    final cleanUid = uid?.trim() ?? '';
    if (cleanUid.isNotEmpty) return cleanUid;

    return fallbackLabel.trim();
  }

  static String currentUserDisplayName({
    LabMembershipModel? membership,
    String fallbackLabel = 'User',
  }) {
    final appState = AppState.instance;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return resolvePersonDisplayName(
      profile: appState.profile,
      membership: membership,
      firebaseDisplayName: firebaseUser?.displayName,
      email: appState.authenticatedUserEmail,
      uid: appState.authenticatedUserId,
      fallbackLabel: fallbackLabel,
    );
  }

  Future<Map<String, String>> resolvePeopleForLab({
    required String labId,
    required Iterable<String> userIds,
    Map<String, String> explicitDisplayNamesByUid = const {},
    Map<String, String> emailByUid = const {},
    String fallbackLabel = '',
  }) async {
    final cleanUserIds = userIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList();

    if (cleanUserIds.isEmpty) {
      return const {};
    }

    final profiles = <String, UserProfile>{};
    final membershipsByUid = <String, LabMembershipModel>{};

    try {
      profiles.addAll(
        await _userProfileService.getUserProfilesByIds(cleanUserIds),
      );
    } catch (_) {
      // Display falls back to stored label/email/UID if profiles are unavailable.
    }

    final cleanLabId = labId.trim();
    if (cleanLabId.isNotEmpty) {
      try {
        final memberships = await _labMembershipService.getMembershipsForLab(
          labId: cleanLabId,
        );
        for (final membership in memberships) {
          final userId = membership.userId.trim();
          if (cleanUserIds.contains(userId)) {
            membershipsByUid[userId] = membership;
          }
        }
      } catch (_) {
        // Membership lookup is best-effort for display only.
      }
    }

    final resolved = <String, String>{};
    for (final userId in cleanUserIds) {
      final displayName = resolvePersonDisplayName(
        explicitDisplayName: explicitDisplayNamesByUid[userId],
        profile: profiles[userId],
        membership: membershipsByUid[userId],
        email: emailByUid[userId],
        uid: userId,
        fallbackLabel: fallbackLabel,
      );
      if (displayName.trim().isNotEmpty) {
        resolved[userId] = displayName.trim();
      }
    }

    return resolved;
  }

  static String? _usableName(String? value) {
    final cleanValue = value?.trim() ?? '';
    return hasUsableDisplayName(cleanValue) ? cleanValue : null;
  }

  static String? _usableEmail(String? value) {
    final cleanValue = value?.trim() ?? '';
    return isLikelyEmail(cleanValue) ? cleanValue : null;
  }
}
