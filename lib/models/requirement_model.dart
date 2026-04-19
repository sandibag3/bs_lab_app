import 'package:cloud_firestore/cloud_firestore.dart';

class RequirementModel {
  final String id;

  // Common
  final String mainType;
  final String brand;
  final String vendor;
  final String quantity;
  final String estimatedCost;
  final String estimatedTotal;
  final String modeOfPurchase;
  final String packSize;

  // Chemical fields
  final String chemicalName;
  final String cas;
  final String catalogNo;
  final String chemicalType;

  // Consumable fields
  final String consumableType;

  // Workflow fields
  final String status;
  final String userName;
  final Timestamp createdAt;
  final String approvedBy;
  final Timestamp? approvedAt;

  RequirementModel({
    required this.id,
    required this.mainType,
    required this.brand,
    required this.vendor,
    required this.quantity,
    required this.estimatedCost,
    required this.estimatedTotal,
    required this.modeOfPurchase,
    required this.packSize,
    required this.chemicalName,
    required this.cas,
    required this.catalogNo,
    required this.chemicalType,
    required this.consumableType,
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
      mainType: data['mainType'] ?? 'chemical',
      brand: data['brand'] ?? '',
      vendor: data['vendor'] ?? '',
      quantity: data['quantity'] ?? '',
      estimatedCost: data['estimatedCost'] ?? '',
      estimatedTotal: data['estimatedTotal'] ?? '',
      modeOfPurchase: data['modeOfPurchase'] ?? '',
      packSize: data['packSize'] ?? '',
      chemicalName: data['chemicalName'] ?? '',
      cas: data['cas'] ?? '',
      catalogNo: data['catalogNo'] ?? '',
      chemicalType: data['chemicalType'] ?? '',
      consumableType: data['consumableType'] ?? '',
      status: data['status'] ?? 'pending',
      userName: data['userName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      approvedBy: data['approvedBy'] ?? '',
      approvedAt: data['approvedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mainType': mainType,
      'brand': brand,
      'vendor': vendor,
      'quantity': quantity,
      'estimatedCost': estimatedCost,
      'estimatedTotal': estimatedTotal,
      'modeOfPurchase': modeOfPurchase,
      'packSize': packSize,
      'chemicalName': chemicalName,
      'cas': cas,
      'catalogNo': catalogNo,
      'chemicalType': chemicalType,
      'consumableType': consumableType,
      'status': status,
      'userName': userName,
      'createdAt': createdAt,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
    };
  }
}