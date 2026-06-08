import 'package:cloud_firestore/cloud_firestore.dart';

class RequirementModel {
  final String id;
  final String labId;

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
  final String? fundId;
  final String? fundNameSnapshot;
  final String? fundCodeSnapshot;
  final double? allocatedAmount;
  final String? fundAllocatedBy;
  final DateTime? fundAllocatedAt;
  final String? fundTransactionId;

  RequirementModel({
    required this.id,
    required this.labId,
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
    this.fundId,
    this.fundNameSnapshot,
    this.fundCodeSnapshot,
    this.allocatedAmount,
    this.fundAllocatedBy,
    this.fundAllocatedAt,
    this.fundTransactionId,
  });

  factory RequirementModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};

    return RequirementModel(
      id: doc.id,
      labId: data['labId'] ?? '',
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
      fundId: _normalizedOptionalString(data['fundId']),
      fundNameSnapshot: _normalizedOptionalString(data['fundNameSnapshot']),
      fundCodeSnapshot: _normalizedOptionalString(data['fundCodeSnapshot']),
      allocatedAmount: _doubleFromValue(data['allocatedAmount']),
      fundAllocatedBy: _normalizedOptionalString(data['fundAllocatedBy']),
      fundAllocatedAt: _dateTimeFromValue(data['fundAllocatedAt']),
      fundTransactionId: _normalizedOptionalString(data['fundTransactionId']),
    );
  }

  bool get hasFundAllocation {
    final cleanFundId = fundId?.trim() ?? '';
    final cleanTransactionId = fundTransactionId?.trim() ?? '';

    return cleanFundId.isNotEmpty &&
        allocatedAmount != null &&
        cleanTransactionId.isNotEmpty;
  }

  String get fundDisplayName {
    final name = fundNameSnapshot?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }

    final code = fundCodeSnapshot?.trim() ?? '';
    if (code.isNotEmpty) {
      return code;
    }

    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      'labId': labId,
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
      'fundId': fundId,
      'fundNameSnapshot': fundNameSnapshot,
      'fundCodeSnapshot': fundCodeSnapshot,
      'allocatedAmount': allocatedAmount,
      'fundAllocatedBy': fundAllocatedBy,
      'fundAllocatedAt': fundAllocatedAt != null
          ? Timestamp.fromDate(fundAllocatedAt!)
          : null,
      'fundTransactionId': fundTransactionId,
    };
  }

  RequirementModel copyWith({
    String? id,
    String? labId,
    String? mainType,
    String? brand,
    String? vendor,
    String? quantity,
    String? estimatedCost,
    String? estimatedTotal,
    String? modeOfPurchase,
    String? packSize,
    String? chemicalName,
    String? cas,
    String? catalogNo,
    String? chemicalType,
    String? consumableType,
    String? status,
    String? userName,
    Timestamp? createdAt,
    String? approvedBy,
    Timestamp? approvedAt,
    bool clearApprovedAt = false,
    String? fundId,
    bool clearFundId = false,
    String? fundNameSnapshot,
    bool clearFundNameSnapshot = false,
    String? fundCodeSnapshot,
    bool clearFundCodeSnapshot = false,
    double? allocatedAmount,
    bool clearAllocatedAmount = false,
    String? fundAllocatedBy,
    bool clearFundAllocatedBy = false,
    DateTime? fundAllocatedAt,
    bool clearFundAllocatedAt = false,
    String? fundTransactionId,
    bool clearFundTransactionId = false,
  }) {
    return RequirementModel(
      id: id ?? this.id,
      labId: labId ?? this.labId,
      mainType: mainType ?? this.mainType,
      brand: brand ?? this.brand,
      vendor: vendor ?? this.vendor,
      quantity: quantity ?? this.quantity,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      modeOfPurchase: modeOfPurchase ?? this.modeOfPurchase,
      packSize: packSize ?? this.packSize,
      chemicalName: chemicalName ?? this.chemicalName,
      cas: cas ?? this.cas,
      catalogNo: catalogNo ?? this.catalogNo,
      chemicalType: chemicalType ?? this.chemicalType,
      consumableType: consumableType ?? this.consumableType,
      status: status ?? this.status,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: clearApprovedAt ? null : (approvedAt ?? this.approvedAt),
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
      fundAllocatedBy: clearFundAllocatedBy
          ? null
          : (fundAllocatedBy ?? this.fundAllocatedBy),
      fundAllocatedAt: clearFundAllocatedAt
          ? null
          : (fundAllocatedAt ?? this.fundAllocatedAt),
      fundTransactionId: clearFundTransactionId
          ? null
          : (fundTransactionId ?? this.fundTransactionId),
    );
  }

  static String? _normalizedOptionalString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static double? _doubleFromValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      return double.tryParse(trimmed);
    }

    return null;
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
}
