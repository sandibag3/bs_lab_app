import 'package:cloud_firestore/cloud_firestore.dart';

class LabMembershipModel {
  final String id;
  final String userId;
  final String labId;
  final String role;
  final String status;
  final String userName;
  final String userEmail;
  final String labName;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final DateTime? membershipStartAt;
  final DateTime? membershipEndAt;
  final DateTime? leftAt;
  final String? leftBy;

  LabMembershipModel({
    required this.id,
    required this.userId,
    required this.labId,
    required this.role,
    required this.status,
    required this.userName,
    required this.userEmail,
    required this.labName,
    required this.createdAt,
    required this.updatedAt,
    this.membershipStartAt,
    this.membershipEndAt,
    this.leftAt,
    this.leftBy,
  });

  factory LabMembershipModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};

    return LabMembershipModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString().trim(),
      labId: (data['labId'] ?? '').toString().trim(),
      role: (data['role'] ?? '').toString().trim(),
      status: (data['status'] ?? 'active').toString().trim(),
      userName: (data['userName'] ?? '').toString().trim(),
      userEmail: (data['userEmail'] ?? '').toString().trim(),
      labName: (data['labName'] ?? '').toString().trim(),
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      membershipStartAt: _dateTimeFromValue(data['membershipStartAt']),
      membershipEndAt: _dateTimeFromValue(data['membershipEndAt']),
      leftAt: _dateTimeFromValue(data['leftAt']),
      leftBy: _normalizedOptionalString(data['leftBy']),
    );
  }

  bool get hasTenure => membershipStartAt != null || membershipEndAt != null;

  bool get isExpired => isExpiredAt(DateTime.now());

  bool isExpiredAt(DateTime now) {
    final endAt = membershipEndAt;
    return endAt != null && now.isAfter(endAt);
  }

  String get effectiveStatus => effectiveStatusAt(DateTime.now());

  String effectiveStatusAt(DateTime now) {
    final normalizedStatus = status.trim().toLowerCase();
    final storedStatus = normalizedStatus.isEmpty ? 'active' : normalizedStatus;
    if (storedStatus == 'active' && isExpiredAt(now)) {
      return 'expired';
    }
    return storedStatus;
  }

  bool get grantsActiveAccess => grantsActiveAccessAt(DateTime.now());

  bool grantsActiveAccessAt(DateTime now) {
    return effectiveStatusAt(now) == 'active';
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'labId': labId,
      'role': role,
      'status': status,
      'userName': userName,
      'userEmail': userEmail,
      'labName': labName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (membershipStartAt != null)
        'membershipStartAt': Timestamp.fromDate(membershipStartAt!),
      if (membershipEndAt != null)
        'membershipEndAt': Timestamp.fromDate(membershipEndAt!),
      'leftAt': leftAt,
      'leftBy': leftBy,
    };
  }

  LabMembershipModel copyWith({
    String? id,
    String? userId,
    String? labId,
    String? role,
    String? status,
    String? userName,
    String? userEmail,
    String? labName,
    Timestamp? createdAt,
    bool clearCreatedAt = false,
    Timestamp? updatedAt,
    bool clearUpdatedAt = false,
    DateTime? membershipStartAt,
    bool clearMembershipStartAt = false,
    DateTime? membershipEndAt,
    bool clearMembershipEndAt = false,
    DateTime? leftAt,
    bool clearLeftAt = false,
    String? leftBy,
    bool clearLeftBy = false,
  }) {
    return LabMembershipModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      labId: labId ?? this.labId,
      role: role ?? this.role,
      status: status ?? this.status,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      labName: labName ?? this.labName,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      membershipStartAt: clearMembershipStartAt
          ? null
          : (membershipStartAt ?? this.membershipStartAt),
      membershipEndAt: clearMembershipEndAt
          ? null
          : (membershipEndAt ?? this.membershipEndAt),
      leftAt: clearLeftAt ? null : (leftAt ?? this.leftAt),
      leftBy: clearLeftBy ? null : (leftBy ?? this.leftBy),
    );
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

  static String? _normalizedOptionalString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
