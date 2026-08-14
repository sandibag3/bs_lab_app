import 'package:cloud_firestore/cloud_firestore.dart';

class LabJoinRequestModel {
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  final String id;
  final String labId;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime? requestedAt;
  final String status;
  final String? reviewedByUid;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final DateTime? membershipStartAt;
  final DateTime? membershipEndAt;

  const LabJoinRequestModel({
    required this.id,
    required this.labId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.requestedAt,
    required this.status,
    this.reviewedByUid,
    this.reviewedByName,
    this.reviewedAt,
    this.membershipStartAt,
    this.membershipEndAt,
  });

  factory LabJoinRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return LabJoinRequestModel(
      id: doc.id,
      labId: (data['labId'] ?? '').toString().trim(),
      userId: (data['userId'] ?? '').toString().trim(),
      userName: (data['userName'] ?? '').toString().trim(),
      userEmail: (data['userEmail'] ?? '').toString().trim(),
      requestedAt: _dateTimeFromValue(data['requestedAt']),
      status: _normalizeStatus(data['status']),
      reviewedByUid: _normalizedOptionalString(data['reviewedByUid']),
      reviewedByName: _normalizedOptionalString(data['reviewedByName']),
      reviewedAt: _dateTimeFromValue(data['reviewedAt']),
      membershipStartAt: _dateTimeFromValue(data['membershipStartAt']),
      membershipEndAt: _dateTimeFromValue(data['membershipEndAt']),
    );
  }

  bool get isPending => status == statusPending;

  Map<String, dynamic> toMap() {
    return {
      'labId': labId.trim(),
      'userId': userId.trim(),
      'userName': userName.trim(),
      'userEmail': userEmail.trim(),
      if (requestedAt != null) 'requestedAt': Timestamp.fromDate(requestedAt!),
      'status': status,
      'reviewedByUid': reviewedByUid,
      'reviewedByName': reviewedByName,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (membershipStartAt != null)
        'membershipStartAt': Timestamp.fromDate(membershipStartAt!),
      if (membershipEndAt != null)
        'membershipEndAt': Timestamp.fromDate(membershipEndAt!),
    };
  }

  static String _normalizeStatus(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    switch (normalized) {
      case statusApproved:
      case statusRejected:
        return normalized;
      case statusPending:
      default:
        return statusPending;
    }
  }

  static String? _normalizedOptionalString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
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
