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
  final DateTime? inventoryAddedAt;
  final String? inventoryRecordId;
  final String? inventoryAddedBy;
  final double? estimatedTotal;
  final String? fundId;
  final String? fundNameSnapshot;
  final String? fundCodeSnapshot;
  final double? allocatedAmount;
  final String? fundTransactionId;
  final String? purchaseOrderId;
  final String? purchaseOrderNumber;
  final String? purchaseOrderStatus;
  final DateTime? purchaseOrderAssignedAt;
  final String? purchaseOrderAssignedBy;
  final double? actualTotal;
  final String? actualCostRecordedBy;
  final DateTime? actualCostRecordedAt;
  final bool costReconciled;
  final DateTime? costReconciledAt;
  final String? costReconciledBy;
  final String? fundAdjustmentTransactionId;
  // positive = actual cost exceeded allocated amount
  // negative = actual cost was lower than allocated amount
  // zero = actual cost matched allocation
  final double? reconciledDeltaAmount;

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
    this.inventoryAddedAt,
    this.inventoryRecordId,
    this.inventoryAddedBy,
    this.estimatedTotal,
    this.fundId,
    this.fundNameSnapshot,
    this.fundCodeSnapshot,
    this.allocatedAmount,
    this.fundTransactionId,
    this.purchaseOrderId,
    this.purchaseOrderNumber,
    this.purchaseOrderStatus,
    this.purchaseOrderAssignedAt,
    this.purchaseOrderAssignedBy,
    this.actualTotal,
    this.actualCostRecordedBy,
    this.actualCostRecordedAt,
    this.costReconciled = false,
    this.costReconciledAt,
    this.costReconciledBy,
    this.fundAdjustmentTransactionId,
    this.reconciledDeltaAmount,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};

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
      inventoryAddedAt: _dateTimeFromValue(data['inventoryAddedAt']),
      inventoryRecordId: _normalizedOptionalString(data['inventoryRecordId']),
      inventoryAddedBy: _normalizedOptionalString(data['inventoryAddedBy']),
      estimatedTotal: _doubleFromValue(data['estimatedTotal']),
      fundId: _normalizedOptionalString(data['fundId']),
      fundNameSnapshot: _normalizedOptionalString(data['fundNameSnapshot']),
      fundCodeSnapshot: _normalizedOptionalString(data['fundCodeSnapshot']),
      allocatedAmount: _doubleFromValue(data['allocatedAmount']),
      fundTransactionId: _normalizedOptionalString(data['fundTransactionId']),
      purchaseOrderId: _normalizedOptionalString(data['purchaseOrderId']),
      purchaseOrderNumber: _normalizedOptionalString(
        data['purchaseOrderNumber'],
      ),
      purchaseOrderStatus: _normalizedOptionalString(
        data['purchaseOrderStatus'],
      ),
      purchaseOrderAssignedAt: _dateTimeFromValue(
        data['purchaseOrderAssignedAt'],
      ),
      purchaseOrderAssignedBy: _normalizedOptionalString(
        data['purchaseOrderAssignedBy'],
      ),
      actualTotal: _doubleFromValue(data['actualTotal']),
      actualCostRecordedBy: _normalizedOptionalString(
        data['actualCostRecordedBy'],
      ),
      actualCostRecordedAt: _dateTimeFromValue(data['actualCostRecordedAt']),
      costReconciled: _boolFromValue(data['costReconciled']),
      costReconciledAt: _dateTimeFromValue(data['costReconciledAt']),
      costReconciledBy: _normalizedOptionalString(data['costReconciledBy']),
      fundAdjustmentTransactionId: _normalizedOptionalString(
        data['fundAdjustmentTransactionId'],
      ),
      reconciledDeltaAmount: _doubleFromValue(data['reconciledDeltaAmount']),
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

  bool get hasActualCost => actualTotal != null;

  bool get hasFundReconciliation {
    final cleanTransactionId = fundAdjustmentTransactionId?.trim() ?? '';
    return costReconciled && cleanTransactionId.isNotEmpty;
  }

  bool get isAssignedToPurchaseOrder {
    final cleanPurchaseOrderId = purchaseOrderId?.trim() ?? '';
    return cleanPurchaseOrderId.isNotEmpty;
  }

  String get purchaseOrderDisplayLabel {
    final cleanPurchaseOrderNumber = purchaseOrderNumber?.trim() ?? '';
    if (cleanPurchaseOrderNumber.isNotEmpty) {
      return cleanPurchaseOrderNumber;
    }

    final cleanPurchaseOrderId = purchaseOrderId?.trim() ?? '';
    if (cleanPurchaseOrderId.isNotEmpty) {
      return cleanPurchaseOrderId;
    }

    return '';
  }

  bool get isCostManagedThroughPurchaseOrder => isAssignedToPurchaseOrder;

  double? get reconciliationDifference => reconciledDeltaAmount;

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
      'inventoryAddedAt': inventoryAddedAt != null
          ? Timestamp.fromDate(inventoryAddedAt!)
          : null,
      'inventoryRecordId': inventoryRecordId,
      'inventoryAddedBy': inventoryAddedBy,
      'estimatedTotal': estimatedTotal,
      'fundId': fundId,
      'fundNameSnapshot': fundNameSnapshot,
      'fundCodeSnapshot': fundCodeSnapshot,
      'allocatedAmount': allocatedAmount,
      'fundTransactionId': fundTransactionId,
      'purchaseOrderId': purchaseOrderId,
      'purchaseOrderNumber': purchaseOrderNumber,
      'purchaseOrderStatus': purchaseOrderStatus,
      'purchaseOrderAssignedAt': purchaseOrderAssignedAt != null
          ? Timestamp.fromDate(purchaseOrderAssignedAt!)
          : null,
      'purchaseOrderAssignedBy': purchaseOrderAssignedBy,
      'actualTotal': actualTotal,
      'actualCostRecordedBy': actualCostRecordedBy,
      'actualCostRecordedAt': actualCostRecordedAt != null
          ? Timestamp.fromDate(actualCostRecordedAt!)
          : null,
      'costReconciled': costReconciled,
      'costReconciledAt': costReconciledAt != null
          ? Timestamp.fromDate(costReconciledAt!)
          : null,
      'costReconciledBy': costReconciledBy,
      'fundAdjustmentTransactionId': fundAdjustmentTransactionId,
      'reconciledDeltaAmount': reconciledDeltaAmount,
    };
  }

  OrderModel copyWith({
    String? id,
    String? requirementId,
    String? labId,
    String? mainType,
    String? chemicalName,
    String? consumableType,
    String? cas,
    String? brand,
    String? vendor,
    String? quantity,
    String? packSize,
    String? modeOfPurchase,
    String? orderedBy,
    Timestamp? orderedAt,
    String? status,
    String? receivedBy,
    Timestamp? deliveredAt,
    bool clearDeliveredAt = false,
    bool? inventoryAdded,
    DateTime? inventoryAddedAt,
    bool clearInventoryAddedAt = false,
    String? inventoryRecordId,
    bool clearInventoryRecordId = false,
    String? inventoryAddedBy,
    bool clearInventoryAddedBy = false,
    double? estimatedTotal,
    bool clearEstimatedTotal = false,
    String? fundId,
    bool clearFundId = false,
    String? fundNameSnapshot,
    bool clearFundNameSnapshot = false,
    String? fundCodeSnapshot,
    bool clearFundCodeSnapshot = false,
    double? allocatedAmount,
    bool clearAllocatedAmount = false,
    String? fundTransactionId,
    bool clearFundTransactionId = false,
    String? purchaseOrderId,
    bool clearPurchaseOrderId = false,
    String? purchaseOrderNumber,
    bool clearPurchaseOrderNumber = false,
    String? purchaseOrderStatus,
    bool clearPurchaseOrderStatus = false,
    DateTime? purchaseOrderAssignedAt,
    bool clearPurchaseOrderAssignedAt = false,
    String? purchaseOrderAssignedBy,
    bool clearPurchaseOrderAssignedBy = false,
    double? actualTotal,
    bool clearActualTotal = false,
    String? actualCostRecordedBy,
    bool clearActualCostRecordedBy = false,
    DateTime? actualCostRecordedAt,
    bool clearActualCostRecordedAt = false,
    bool? costReconciled,
    DateTime? costReconciledAt,
    bool clearCostReconciledAt = false,
    String? costReconciledBy,
    bool clearCostReconciledBy = false,
    String? fundAdjustmentTransactionId,
    bool clearFundAdjustmentTransactionId = false,
    double? reconciledDeltaAmount,
    bool clearReconciledDeltaAmount = false,
  }) {
    return OrderModel(
      id: id ?? this.id,
      requirementId: requirementId ?? this.requirementId,
      labId: labId ?? this.labId,
      mainType: mainType ?? this.mainType,
      chemicalName: chemicalName ?? this.chemicalName,
      consumableType: consumableType ?? this.consumableType,
      cas: cas ?? this.cas,
      brand: brand ?? this.brand,
      vendor: vendor ?? this.vendor,
      quantity: quantity ?? this.quantity,
      packSize: packSize ?? this.packSize,
      modeOfPurchase: modeOfPurchase ?? this.modeOfPurchase,
      orderedBy: orderedBy ?? this.orderedBy,
      orderedAt: orderedAt ?? this.orderedAt,
      status: status ?? this.status,
      receivedBy: receivedBy ?? this.receivedBy,
      deliveredAt: clearDeliveredAt ? null : (deliveredAt ?? this.deliveredAt),
      inventoryAdded: inventoryAdded ?? this.inventoryAdded,
      inventoryAddedAt: clearInventoryAddedAt
          ? null
          : (inventoryAddedAt ?? this.inventoryAddedAt),
      inventoryRecordId: clearInventoryRecordId
          ? null
          : (inventoryRecordId ?? this.inventoryRecordId),
      inventoryAddedBy: clearInventoryAddedBy
          ? null
          : (inventoryAddedBy ?? this.inventoryAddedBy),
      estimatedTotal: clearEstimatedTotal
          ? null
          : (estimatedTotal ?? this.estimatedTotal),
      fundId: clearFundId ? null : (fundId ?? this.fundId),
      fundNameSnapshot: clearFundNameSnapshot
          ? null
          : (fundNameSnapshot ?? this.fundNameSnapshot),
      fundCodeSnapshot: clearFundCodeSnapshot
          ? null
          : (fundCodeSnapshot ?? this.fundCodeSnapshot),
      allocatedAmount: clearAllocatedAmount
          ? null
          : (allocatedAmount ?? this.allocatedAmount),
      fundTransactionId: clearFundTransactionId
          ? null
          : (fundTransactionId ?? this.fundTransactionId),
      purchaseOrderId: clearPurchaseOrderId
          ? null
          : (purchaseOrderId ?? this.purchaseOrderId),
      purchaseOrderNumber: clearPurchaseOrderNumber
          ? null
          : (purchaseOrderNumber ?? this.purchaseOrderNumber),
      purchaseOrderStatus: clearPurchaseOrderStatus
          ? null
          : (purchaseOrderStatus ?? this.purchaseOrderStatus),
      purchaseOrderAssignedAt: clearPurchaseOrderAssignedAt
          ? null
          : (purchaseOrderAssignedAt ?? this.purchaseOrderAssignedAt),
      purchaseOrderAssignedBy: clearPurchaseOrderAssignedBy
          ? null
          : (purchaseOrderAssignedBy ?? this.purchaseOrderAssignedBy),
      actualTotal: clearActualTotal ? null : (actualTotal ?? this.actualTotal),
      actualCostRecordedBy: clearActualCostRecordedBy
          ? null
          : (actualCostRecordedBy ?? this.actualCostRecordedBy),
      actualCostRecordedAt: clearActualCostRecordedAt
          ? null
          : (actualCostRecordedAt ?? this.actualCostRecordedAt),
      costReconciled: costReconciled ?? this.costReconciled,
      costReconciledAt: clearCostReconciledAt
          ? null
          : (costReconciledAt ?? this.costReconciledAt),
      costReconciledBy: clearCostReconciledBy
          ? null
          : (costReconciledBy ?? this.costReconciledBy),
      fundAdjustmentTransactionId: clearFundAdjustmentTransactionId
          ? null
          : (fundAdjustmentTransactionId ?? this.fundAdjustmentTransactionId),
      reconciledDeltaAmount: clearReconciledDeltaAmount
          ? null
          : (reconciledDeltaAmount ?? this.reconciledDeltaAmount),
    );
  }

  static double? _doubleFromValue(Object? value) {
    if (value is num) {
      final normalized = value.toDouble();
      return normalized.isFinite ? normalized : null;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      final parsed = double.tryParse(trimmed);
      if (parsed == null || !parsed.isFinite) {
        return null;
      }

      return parsed;
    }

    return null;
  }

  static String? _normalizedOptionalString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static DateTime? _dateTimeFromValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static bool _boolFromValue(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }

    return false;
  }
}
