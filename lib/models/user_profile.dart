import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String prefix;
  final String name;
  final String joinAs;
  final String contactNumber;
  final String rollNo;
  final String batch;
  final String dob;
  final String photoUrl;
  final String presentAddress;
  final String permanentAddress;
  final String emergencyContactPerson;
  final String emergencyRelationship;
  final String emergencyContactNumber;
  final String bloodGroup;
  final String hobbies;
  final String about;
  final bool profileCompleted;
  final DateTime? firstLoginAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.prefix,
    required this.name,
    required this.joinAs,
    required this.contactNumber,
    required this.rollNo,
    required this.batch,
    required this.dob,
    required this.photoUrl,
    required this.presentAddress,
    required this.permanentAddress,
    required this.emergencyContactPerson,
    required this.emergencyRelationship,
    required this.emergencyContactNumber,
    required this.bloodGroup,
    required this.hobbies,
    required this.about,
    required this.profileCompleted,
    required this.firstLoginAt,
    required this.updatedAt,
  });

  factory UserProfile.empty() {
    return UserProfile(
      prefix: '',
      name: 'Your Name',
      joinAs: '',
      contactNumber: '',
      rollNo: '',
      batch: '',
      dob: '',
      photoUrl: '',
      presentAddress: '',
      permanentAddress: '',
      emergencyContactPerson: '',
      emergencyRelationship: '',
      emergencyContactNumber: '',
      bloodGroup: '',
      hobbies: '',
      about: '',
      profileCompleted: false,
      firstLoginAt: null,
      updatedAt: null,
    );
  }

  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return UserProfile(
      prefix: (data['prefix'] ?? '').toString(),
      name: (data['name'] ?? 'Your Name').toString(),
      joinAs: (data['joinAs'] ?? '').toString(),
      contactNumber: (data['contactNumber'] ?? '').toString(),
      rollNo: (data['rollNo'] ?? '').toString(),
      batch: (data['batch'] ?? '').toString(),
      dob: (data['dateOfBirth'] ?? data['dob'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      presentAddress: (data['presentAddress'] ?? '').toString(),
      permanentAddress: (data['permanentAddress'] ?? '').toString(),
      emergencyContactPerson: (data['emergencyContactPerson'] ?? '').toString(),
      emergencyRelationship: (data['emergencyRelationship'] ?? '').toString(),
      emergencyContactNumber: (data['emergencyContactNumber'] ?? '').toString(),
      bloodGroup: (data['bloodGroup'] ?? '').toString(),
      hobbies: (data['hobbies'] ?? '').toString(),
      about: (data['about'] ?? '').toString(),
      profileCompleted: data['profileCompleted'] == true,
      firstLoginAt: _dateTimeFromValue(data['firstLoginAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  UserProfile copyWith({
    String? prefix,
    String? name,
    String? joinAs,
    String? contactNumber,
    String? rollNo,
    String? batch,
    String? dob,
    String? photoUrl,
    String? presentAddress,
    String? permanentAddress,
    String? emergencyContactPerson,
    String? emergencyRelationship,
    String? emergencyContactNumber,
    String? bloodGroup,
    String? hobbies,
    String? about,
    bool? profileCompleted,
    DateTime? firstLoginAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      prefix: prefix ?? this.prefix,
      name: name ?? this.name,
      joinAs: joinAs ?? this.joinAs,
      contactNumber: contactNumber ?? this.contactNumber,
      rollNo: rollNo ?? this.rollNo,
      batch: batch ?? this.batch,
      dob: dob ?? this.dob,
      photoUrl: photoUrl ?? this.photoUrl,
      presentAddress: presentAddress ?? this.presentAddress,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      emergencyContactPerson:
          emergencyContactPerson ?? this.emergencyContactPerson,
      emergencyRelationship:
          emergencyRelationship ?? this.emergencyRelationship,
      emergencyContactNumber:
          emergencyContactNumber ?? this.emergencyContactNumber,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      hobbies: hobbies ?? this.hobbies,
      about: about ?? this.about,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      firstLoginAt: firstLoginAt ?? this.firstLoginAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get requiresAcademicFields {
    return joinAs == 'PhD Scholar' || joinAs == 'Undergrad Student';
  }

  bool get isComplete {
    final baseComplete =
        prefix.trim().isNotEmpty &&
        name.trim().isNotEmpty &&
        name.trim() != 'Your Name' &&
        joinAs.trim().isNotEmpty &&
        contactNumber.trim().isNotEmpty &&
        dob.trim().isNotEmpty &&
        photoUrl.trim().isNotEmpty;

    if (!baseComplete) {
      return false;
    }

    if (!requiresAcademicFields) {
      return true;
    }

    return rollNo.trim().isNotEmpty && batch.trim().isNotEmpty;
  }

  bool get shouldShowCompletionReminder {
    final startedAt = firstLoginAt;
    if (profileCompleted || startedAt == null) {
      return false;
    }

    return DateTime.now().difference(startedAt).inDays >= 7;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'prefix': prefix.trim(),
      'name': name.trim(),
      'joinAs': joinAs.trim(),
      'contactNumber': contactNumber.trim(),
      'rollNo': rollNo.trim(),
      'batch': batch.trim(),
      'dateOfBirth': dob.trim(),
      'photoUrl': photoUrl.trim(),
      'presentAddress': presentAddress.trim(),
      'permanentAddress': permanentAddress.trim(),
      'emergencyContactPerson': emergencyContactPerson.trim(),
      'emergencyRelationship': emergencyRelationship.trim(),
      'emergencyContactNumber': emergencyContactNumber.trim(),
      'bloodGroup': bloodGroup.trim(),
      'hobbies': hobbies.trim(),
      'about': about.trim(),
      'profileCompleted': isComplete,
      if (firstLoginAt != null)
        'firstLoginAt': Timestamp.fromDate(firstLoginAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
