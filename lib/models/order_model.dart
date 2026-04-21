import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String requirementId;
  final String labId;
  final String mainType;
  final String chemicalName;
  final String consumableType;
  final String cas;
  final String brand;
  final String vendor;
  final String quantity;
  final String packSize;
  final String modeOfPurchase;
  final String orderedBy;
  final Timestamp orderedAt;
  final String status;
  final String receivedBy;
  final Timestamp? deliveredAt;
  final bool inventoryAdded;

  OrderModel({
    required this.id,
    required this.requirementId,
    required this.labId,
    required this.mainType,
    required this.chemicalName,
    required this.consumableType,
    required this.cas,
    required this.brand,
    required this.vendor,
    required this.quantity,
    required this.packSize,
    required this.modeOfPurchase,
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
      labId: data['labId'] ?? '',
      mainType: data['mainType'] ?? 'chemical',
      chemicalName: data['chemicalName'] ?? '',
      consumableType: data['consumableType'] ?? '',
      cas: data['cas'] ?? '',
      brand: data['brand'] ?? '',
      vendor: data['vendor'] ?? '',
      quantity: data['quantity'] ?? '',
      packSize: data['packSize'] ?? '',
      modeOfPurchase: data['modeOfPurchase'] ?? '',
      orderedBy: data['orderedBy'] ?? '',
      orderedAt: data['orderedAt'] ?? Timestamp.now(),
      status: data['status'] ?? 'ordered',
      receivedBy: data['receivedBy'] ?? '',
      deliveredAt: data['deliveredAt'],
      inventoryAdded: data['inventoryAdded'] ?? false,
    );
  }

  String get normalizedMainType {
    final value = mainType.trim().toLowerCase();
    return value.isEmpty ? 'chemical' : value;
  }

  bool get isConsumable => normalizedMainType == 'consumable';
  bool get isChemical => !isConsumable;
  bool get requiresInventoryIntake => true;

  String get displayName {
    final chemical = chemicalName.trim();
    final consumable = consumableType.trim();

    if (isConsumable) {
      if (consumable.isNotEmpty) return consumable;
      if (chemical.isNotEmpty) return chemical;
      return 'Consumable';
    }

    if (chemical.isNotEmpty) return chemical;
    if (consumable.isNotEmpty) return consumable;
    return 'Chemical';
  }

  String get typeLabel => isConsumable ? 'Consumable' : 'Chemical';

  Map<String, dynamic> toMap() {
    return {
      'requirementId': requirementId,
      'labId': labId,
      'mainType': mainType,
      'chemicalName': chemicalName,
      'consumableType': consumableType,
      'cas': cas,
      'brand': brand,
      'vendor': vendor,
      'quantity': quantity,
      'packSize': packSize,
      'modeOfPurchase': modeOfPurchase,
      'orderedBy': orderedBy,
      'orderedAt': orderedAt,
      'status': status,
      'receivedBy': receivedBy,
      'deliveredAt': deliveredAt,
      'inventoryAdded': inventoryAdded,
    };
  }
}
