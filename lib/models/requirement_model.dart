import 'package:cloud_firestore/cloud_firestore.dart';

class RequirementModel {
  final String id;
  final String chemicalName;
  final String cas;
  final String brand;
  final String quantity;
  final String status;
  final String userName;
  final Timestamp createdAt;
  final String approvedBy;
  final Timestamp? approvedAt;

  RequirementModel({
    required this.id,
    required this.chemicalName,
    required this.cas,
    required this.brand,
    required this.quantity,
    required this.status,
    required this.userName,
    required this.createdAt,
    required this.approvedBy,
    required this.approvedAt,
  });

  factory RequirementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RequirementModel(
      id: doc.id,
      chemicalName: data['chemicalName'] ?? '',
      cas: data['cas'] ?? '',
      brand: data['brand'] ?? '',
      quantity: data['quantity'] ?? '',
      status: data['status'] ?? 'pending',
      userName: data['userName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      approvedBy: data['approvedBy'] ?? '',
      approvedAt: data['approvedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chemicalName': chemicalName,
      'cas': cas,
      'brand': brand,
      'quantity': quantity,
      'status': status,
      'userName': userName,
      'createdAt': createdAt,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
    };
  }
}