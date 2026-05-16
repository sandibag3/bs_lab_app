import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/lab_context_model.dart';
import 'models/lab_membership_model.dart';
import 'models/user_profile.dart';
import 'services/lab_membership_service.dart';
import 'services/user_profile_service.dart';

enum DemoUserRole {
  piAdmin('PI/Admin'),
  researcher('Researcher');

  final String label;

  const DemoUserRole(this.label);
}

class AppState extends ChangeNotifier {
  static const String _nameKey = 'profile_name';
  static const String _rollNoKey = 'profile_roll_no';
  static const String _batchKey = 'profile_batch';
  static const String _dobKey = 'profile_dob';
  static const String _hobbiesKey = 'profile_hobbies';
  static const String _aboutKey = 'profile_about';
  static const String _demoRoleKey = 'demo_role';
  static const String _selectedLabIdKey = 'selected_lab_id';
  static const String _selectedLabNameKey = 'selected_lab_name';
  static const String _selectedLabLocalRoleKey = 'selected_lab_local_role';
  static const String _selectedLabUserIdKey = 'selected_lab_user_id';

  static const String demoLabId = 'labmate-demo-lab';
  static const String demoLabName = 'Labmate Demo Lab';

  static AppState? _instance;
  final LabMembershipService _labMembershipService = LabMembershipService();
  final UserProfileService _userProfileService = UserProfileService();

  UserProfile _profile = UserProfile.empty();
  bool _isLoaded = false;
  String _demoRole = DemoUserRole.researcher.name;
  String _selectedLabId = '';
  String _selectedLabName = '';
  String _selectedLabLocalRole = '';
  String _selectedLabUserId = '';
  String _selectedLabMembershipRole = '';
  bool _isRefreshingSelectedLabRole = false;
  bool _hasAttemptedSelectedLabMembershipLoad = false;

  AppState() {
    _instance = this;
  }

  static AppState get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('AppState has not been initialized.');
    }
    return instance;
  }

  UserProfile get profile => _profile;
  bool get shouldShowProfileReminder => _profile.shouldShowCompletionReminder;
  bool get isLoaded => _isLoaded;
  String get demoRole => _demoRole;
  String get selectedLabId => _selectedLabId;
  String get selectedLabName => _selectedLabName;
  String get selectedLabLocalRole => _selectedLabLocalRole;
  String get selectedLabUserId => _selectedLabUserId;
  String get selectedLabMembershipRole => _selectedLabMembershipRole;
  bool get hasResolvedLabMembership =>
      _selectedLabMembershipRole.trim().isNotEmpty;
  bool get isRefreshingSelectedLabRole => _isRefreshingSelectedLabRole;
  bool get hasAttemptedSelectedLabMembershipLoad =>
      _hasAttemptedSelectedLabMembershipLoad;
  LabContextModel get labContext => LabContextModel(
    selectedLabId: _selectedLabId,
    selectedLabName: _selectedLabName,
  );
  DemoUserRole get demoUserRole {
    return DemoUserRole.values.firstWhere(
      (role) => role.name == _demoRole,
      orElse: () => DemoUserRole.researcher,
    );
  }

  bool get isPiAdmin => currentRoleName == DemoUserRole.piAdmin.name;
  bool get hasSelectedLab => labContext.hasSelection;
  bool get isDemoLabSelected => selectedLabId.trim() == demoLabId;
  bool get isLocalFallbackLabSelected =>
      selectedLabId.trim().startsWith('local-');
  bool get shouldIncludeLegacyLabData =>
      selectedLabId.trim().isEmpty || isDemoLabSelected;

  String get authenticatedUserId {
    return FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  }

  String get currentRoleName {
    if (isDemoLabSelected) {
      return demoUserRole.name;
    }

    final membershipRole = _selectedLabMembershipRole.trim();
    if (membershipRole.isNotEmpty) {
      return membershipRole;
    }

    final localRole = _selectedLabLocalRole.trim();
    if (localRole.isNotEmpty) {
      return localRole;
    }

    return DemoUserRole.researcher.name;
  }

  String get currentRoleLabel => roleLabelFor(currentRoleName);

  String get authenticatedUserName {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) {
      return email;
    }

    return 'User';
  }

  String get authenticatedUserEmail {
    return FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
  }

  String roleLabelFor(String roleName) {
    const roleLabels = {
      'piAdmin': 'PI/Admin',
      'phdScholar': 'PhD Scholar',
      'undergradStudent': 'Undergrad Student',
      'projectStudent': 'Project Student',
      'postdocFellow': 'Postdoc Fellow',
      'labManager': 'Lab Manager',
      'researcher': 'Researcher',
    };
    final directLabel = roleLabels[roleName.trim()];
    if (directLabel != null) {
      return directLabel;
    }

    return DemoUserRole.values
        .firstWhere(
          (role) => role.name == roleName,
          orElse: () => DemoUserRole.researcher,
        )
        .label;
  }

  Future<void> _loadSelectedLabRole() async {
    _selectedLabMembershipRole = '';

    if (_selectedLabId.trim().isEmpty ||
        isDemoLabSelected ||
        isLocalFallbackLabSelected) {
      _hasAttemptedSelectedLabMembershipLoad = false;
      return;
    }

    final userId = authenticatedUserId;
    if (userId.isEmpty) {
      _hasAttemptedSelectedLabMembershipLoad = false;
      return;
    }

    _hasAttemptedSelectedLabMembershipLoad = true;

    LabMembershipModel? membership;
    try {
      membership = await _labMembershipService.getMembership(
        userId: userId,
        labId: _selectedLabId,
      );
    } catch (_) {
      membership = null;
    }

    if (membership == null) {
      return;
    }

    final status = membership.status.trim().toLowerCase();
    if (status.isNotEmpty && status != 'active') {
      return;
    }

    _selectedLabMembershipRole = membership.role.trim();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    _profile = UserProfile(
      prefix: '',
      name: prefs.getString(_nameKey) ?? 'Your Name',
      joinAs: '',
      contactNumber: '',
      rollNo: prefs.getString(_rollNoKey) ?? '',
      batch: prefs.getString(_batchKey) ?? '',
      dob: prefs.getString(_dobKey) ?? '',
      photoUrl: '',
      presentAddress: '',
      permanentAddress: '',
      emergencyContactPerson: '',
      emergencyRelationship: '',
      emergencyContactNumber: '',
      bloodGroup: '',
      hobbies: prefs.getString(_hobbiesKey) ?? '',
      about: prefs.getString(_aboutKey) ?? '',
      profileCompleted: false,
      firstLoginAt: null,
      updatedAt: null,
    );
    _demoRole = prefs.getString(_demoRoleKey) ?? DemoUserRole.researcher.name;
    _selectedLabId = prefs.getString(_selectedLabIdKey) ?? '';
    _selectedLabName = prefs.getString(_selectedLabNameKey) ?? '';
    _selectedLabLocalRole = prefs.getString(_selectedLabLocalRoleKey) ?? '';
    _selectedLabUserId = prefs.getString(_selectedLabUserIdKey) ?? '';
    _hasAttemptedSelectedLabMembershipLoad = false;

    await _loadSelectedLabRole();

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedProfile = profile.copyWith(
      profileCompleted: profile.isComplete,
      firstLoginAt: profile.firstLoginAt ?? _profile.firstLoginAt,
    );

    await prefs.setString(_nameKey, updatedProfile.name);
    await prefs.setString(_rollNoKey, updatedProfile.rollNo);
    await prefs.setString(_batchKey, updatedProfile.batch);
    await prefs.setString(_dobKey, updatedProfile.dob);
    await prefs.setString(_hobbiesKey, updatedProfile.hobbies);
    await prefs.setString(_aboutKey, updatedProfile.about);

    final userId = authenticatedUserId;
    if (userId.isNotEmpty) {
      await _userProfileService.saveUserProfile(
        userId: userId,
        email: authenticatedUserEmail,
        profile: updatedProfile,
      );
    }

    _profile = updatedProfile;
    notifyListeners();
  }

  Future<void> saveDemoRole(DemoUserRole role) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_demoRoleKey, role.name);

    _demoRole = role.name;
    notifyListeners();
  }

  Future<bool> resolveAuthenticatedLabContext() async {
    final userId = authenticatedUserId;
    if (userId.isEmpty) {
      return false;
    }

    final selectedLabBelongsToDifferentUser =
        _selectedLabUserId.trim().isNotEmpty &&
        _selectedLabUserId.trim() != userId;
    if (selectedLabBelongsToDifferentUser) {
      await clearSessionContext();
    }

    await loadAuthenticatedUserProfile();

    final savedLabBelongsToUser =
        _selectedLabUserId.trim().isEmpty ||
        _selectedLabUserId.trim() == userId;

    if (hasSelectedLab && !isDemoLabSelected && savedLabBelongsToUser) {
      if (_selectedLabUserId.trim().isEmpty) {
        await _saveSelectedLabUserId(userId);
      }

      if (!isLocalFallbackLabSelected &&
          !hasResolvedLabMembership &&
          !isRefreshingSelectedLabRole &&
          !hasAttemptedSelectedLabMembershipLoad) {
        await refreshSelectedLabRole();
      }
      return true;
    }

    List<LabMembershipModel> memberships;
    try {
      memberships = await _labMembershipService.getMembershipsForUser(
        userId: userId,
      );
    } catch (_) {
      memberships = [];
    }

    if (memberships.isEmpty) {
      return false;
    }

    final membership = memberships.firstWhere(
      (membership) => membership.labId.trim().isNotEmpty,
      orElse: () => memberships.first,
    );

    if (membership.labId.trim().isEmpty) {
      return false;
    }

    await saveSelectedLabContextWithRole(
      LabContextModel(
        selectedLabId: membership.labId,
        selectedLabName: membership.labName.trim().isEmpty
            ? membership.labId
            : membership.labName,
      ),
      localRoleName: '',
    );

    return true;
  }

  Future<void> loadAuthenticatedUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid.trim() ?? '';
    if (userId.isEmpty) {
      return;
    }

    try {
      final loadedProfile = await _userProfileService.getOrCreateUserProfile(
        userId: userId,
        email: authenticatedUserEmail,
        accountCreatedAt: user?.metadata.creationTime,
      );

      _profile = loadedProfile;
      notifyListeners();
    } catch (_) {
      if (_profile.firstLoginAt == null) {
        _profile = _profile.copyWith(
          firstLoginAt: user?.metadata.creationTime ?? DateTime.now(),
          profileCompleted: _profile.isComplete,
        );
        notifyListeners();
      }
    }
  }

  Future<void> saveSelectedLabContext(LabContextModel labContext) async {
    await saveSelectedLabContextWithRole(labContext);
  }

  Future<void> saveSelectedLabContextWithRole(
    LabContextModel labContext, {
    String localRoleName = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authenticatedUserId;

    await prefs.setString(_selectedLabIdKey, labContext.selectedLabId);
    await prefs.setString(_selectedLabNameKey, labContext.selectedLabName);
    await prefs.setString(_selectedLabLocalRoleKey, localRoleName);
    await prefs.setString(_selectedLabUserIdKey, userId);

    _selectedLabId = labContext.selectedLabId;
    _selectedLabName = labContext.selectedLabName;
    _selectedLabLocalRole = localRoleName;
    _selectedLabUserId = userId;
    _hasAttemptedSelectedLabMembershipLoad = false;

    await _loadSelectedLabRole();

    notifyListeners();
  }

  Future<void> enterDemoLab() async {
    await saveSelectedLabContextWithRole(
      const LabContextModel(
        selectedLabId: demoLabId,
        selectedLabName: demoLabName,
      ),
      localRoleName: '',
    );
  }

  Future<void> refreshSelectedLabRole() async {
    if (_isRefreshingSelectedLabRole) return;

    _isRefreshingSelectedLabRole = true;
    try {
      await _loadSelectedLabRole();
    } finally {
      _isRefreshingSelectedLabRole = false;
      notifyListeners();
    }
  }

  Future<void> updateSelectedLabName(String labName) async {
    final cleanLabName = labName.trim();
    if (cleanLabName.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedLabNameKey, cleanLabName);

    _selectedLabName = cleanLabName;
    notifyListeners();
  }

  Future<void> _saveSelectedLabUserId(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedLabUserIdKey, cleanUserId);

    _selectedLabUserId = cleanUserId;
  }

  Future<void> clearSessionContext() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_selectedLabIdKey);
    await prefs.remove(_selectedLabNameKey);
    await prefs.remove(_selectedLabLocalRoleKey);
    await prefs.remove(_selectedLabUserIdKey);

    _selectedLabId = '';
    _selectedLabName = '';
    _selectedLabLocalRole = '';
    _selectedLabUserId = '';
    _selectedLabMembershipRole = '';
    _hasAttemptedSelectedLabMembershipLoad = false;
    _isRefreshingSelectedLabRole = false;

    notifyListeners();
  }

  bool matchesSelectedLabId(String? docLabId) {
    final currentLabId = selectedLabId.trim();
    final candidateLabId = (docLabId ?? '').trim();

    if (currentLabId.isEmpty) {
      return true;
    }

    if (candidateLabId.isEmpty) {
      return shouldIncludeLegacyLabData;
    }

    return candidateLabId == currentLabId;
  }

  String resolveWriteLabId([String? preferredLabId]) {
    final explicitLabId = (preferredLabId ?? '').trim();
    if (explicitLabId.isNotEmpty) {
      return explicitLabId;
    }

    return selectedLabId.trim();
  }
}
