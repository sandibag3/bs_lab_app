import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_profile.dart';

class AppState extends ChangeNotifier {
  static const String _nameKey = 'profile_name';
  static const String _rollNoKey = 'profile_roll_no';
  static const String _batchKey = 'profile_batch';
  static const String _dobKey = 'profile_dob';
  static const String _hobbiesKey = 'profile_hobbies';
  static const String _aboutKey = 'profile_about';

  UserProfile _profile = UserProfile.empty();
  bool _isLoaded = false;

  UserProfile get profile => _profile;
  bool get isLoaded => _isLoaded;

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
}