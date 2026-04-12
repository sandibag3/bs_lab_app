class UserProfile {
  final String name;
  final String rollNo;
  final String batch;
  final String dob;
  final String hobbies;
  final String about;

  const UserProfile({
    required this.name,
    required this.rollNo,
    required this.batch,
    required this.dob,
    required this.hobbies,
    required this.about,
  });

  factory UserProfile.empty() {
    return const UserProfile(
      name: 'Your Name',
      rollNo: '',
      batch: '',
      dob: '',
      hobbies: '',
      about: '',
    );
  }

  UserProfile copyWith({
    String? name,
    String? rollNo,
    String? batch,
    String? dob,
    String? hobbies,
    String? about,
  }) {
    return UserProfile(
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      batch: batch ?? this.batch,
      dob: dob ?? this.dob,
      hobbies: hobbies ?? this.hobbies,
      about: about ?? this.about,
    );
  }
}