import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/lab_context_model.dart';
import 'models/lab_membership_model.dart';
import 'models/user_profile.dart';
import 'services/lab_membership_service.dart';

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

  static const String demoLabId = 'labmate-demo-lab';
  static const String demoLabName = 'Labmate Demo Lab';

  static AppState? _instance;
  final LabMembershipService _labMembershipService = LabMembershipService();

  UserProfile _profile = UserProfile.empty();
  bool _isLoaded = false;
  String _demoRole = DemoUserRole.researcher.name;
  String _selectedLabId = '';
  String _selectedLabName = '';
  String _selectedLabLocalRole = '';
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
  bool get isLoaded => _isLoaded;
  String get demoRole => _demoRole;
  String get selectedLabId => _selectedLabId;
  String get selectedLabName => _selectedLabName;
  String get selectedLabLocalRole => _selectedLabLocalRole;
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
    return FirebaseAuth.instance.currentUser?.uid?.trim() ?? '';
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
    return DemoUserRole.values.firstWhere(
      (role) => role.name == roleName,
      orElse: () => DemoUserRole.researcher,
    ).label;
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
      name: prefs.getString(_nameKey) ?? 'Your Name',
      rollNo: prefs.getString(_rollNoKey) ?? '',
      batch: prefs.getString(_batchKey) ?? '',
      dob: prefs.getString(_dobKey) ?? '',
      hobbies: prefs.getString(_hobbiesKey) ?? '',
      about: prefs.getString(_aboutKey) ?? '',
    );
    _demoRole = prefs.getString(_demoRoleKey) ?? DemoUserRole.researcher.name;
    _selectedLabId = prefs.getString(_selectedLabIdKey) ?? '';
    _selectedLabName = prefs.getString(_selectedLabNameKey) ?? '';
    _selectedLabLocalRole =
        prefs.getString(_selectedLabLocalRoleKey) ?? '';
    _hasAttemptedSelectedLabMembershipLoad = false;

    await _loadSelectedLabRole();

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_nameKey, profile.name);
    await prefs.setString(_rollNoKey, profile.rollNo);
    await prefs.setString(_batchKey, profile.batch);
    await prefs.setString(_dobKey, profile.dob);
    await prefs.setString(_hobbiesKey, profile.hobbies);
    await prefs.setString(_aboutKey, profile.about);

    _profile = profile;
    notifyListeners();
  }

  Future<void> saveDemoRole(DemoUserRole role) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_demoRoleKey, role.name);

    _demoRole = role.name;
    notifyListeners();
  }

  Future<void> saveSelectedLabContext(LabContextModel labContext) async {
    await saveSelectedLabContextWithRole(labContext);
  }

  Future<void> saveSelectedLabContextWithRole(
    LabContextModel labContext, {
    String localRoleName = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_selectedLabIdKey, labContext.selectedLabId);
    await prefs.setString(_selectedLabNameKey, labContext.selectedLabName);
    await prefs.setString(_selectedLabLocalRoleKey, localRoleName);

    _selectedLabId = labContext.selectedLabId;
    _selectedLabName = labContext.selectedLabName;
    _selectedLabLocalRole = localRoleName;
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
