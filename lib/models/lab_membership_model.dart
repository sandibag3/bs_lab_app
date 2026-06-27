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
    this.leftAt,
    this.leftBy,
  });

  factory LabMembershipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return LabMembershipModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      labId: data['labId'] ?? '',
      role: data['role'] ?? '',
      status: data['status'] ?? 'active',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      labName: data['labName'] ?? '',
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      leftAt: _dateTimeFromValue(data['leftAt']),
      leftBy: (data['leftBy'] as String?)?.trim(),
    );
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
      'leftAt': leftAt,
      'leftBy': leftBy,
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
