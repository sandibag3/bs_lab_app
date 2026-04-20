import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_profile.dart';

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

  static AppState? _instance;

  UserProfile _profile = UserProfile.empty();
  bool _isLoaded = false;
  String _demoRole = DemoUserRole.researcher.name;

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
  DemoUserRole get demoUserRole {
    return DemoUserRole.values.firstWhere(
      (role) => role.name == _demoRole,
      orElse: () => DemoUserRole.researcher,
    );
  }

  bool get isPiAdmin => demoUserRole == DemoUserRole.piAdmin;

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
}
