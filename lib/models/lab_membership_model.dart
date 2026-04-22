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
    };
  }
}
