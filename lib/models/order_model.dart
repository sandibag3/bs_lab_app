import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String requirementId;
  final String chemicalName;
  final String cas;
  final String brand;
  final String quantity;
  final String orderedBy;
  final Timestamp orderedAt;
  final String status;
  final String receivedBy;
  final Timestamp? deliveredAt;
  final bool inventoryAdded;

  OrderModel({
    required this.id,
    required this.requirementId,
    required this.chemicalName,
    required this.cas,
    required this.brand,
    required this.quantity,
    required this.orderedBy,
    required this.orderedAt,
    required this.status,
    required this.receivedBy,
    required this.deliveredAt,
    required this.inventoryAdded,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrderModel(
      id: doc.id,
      requirementId: data['requirementId'] ?? '',
      chemicalName: data['chemicalName'] ?? '',
      cas: data['cas'] ?? '',
      brand: data['brand'] ?? '',
      quantity: data['quantity'] ?? '',
      orderedBy: data['orderedBy'] ?? '',
      orderedAt: data['orderedAt'] ?? Timestamp.now(),
      status: data['status'] ?? 'ordered',
      receivedBy: data['receivedBy'] ?? '',
      deliveredAt: data['deliveredAt'],
      inventoryAdded: data['inventoryAdded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requirementId': requirementId,
      'chemicalName': chemicalName,
      'cas': cas,
      'brand': brand,
      'quantity': quantity,
      'orderedBy': orderedBy,
      'orderedAt': orderedAt,
      'status': status,
      'receivedBy': receivedBy,
      'deliveredAt': deliveredAt,
      'inventoryAdded': inventoryAdded,
    };
  }
}