import 'package:cloud_firestore/cloud_firestore.dart';

class FundTransactionModel {
  static const String typeAllocation = 'allocation';
  static const String statusActive = 'active';

  final String id;
  final String labId;
  final String fundId;
  final String requirementId;
  final String type;
  final String status;
  final double amount;
  final String itemNameSnapshot;
  final String? fundNameSnapshot;
  final String? fundCodeSnapshot;
  final String? purchaseOrderId;
  final String? purchaseOrderNumber;
  final String createdBy;
  final DateTime? createdAt;
  final String? notes;

  FundTransactionModel({
    required String id,
    required String labId,
    required String fundId,
    required String requirementId,
    required String type,
    required String status,
    required double amount,
    required String itemNameSnapshot,
    String? fundNameSnapshot,
    String? fundCodeSnapshot,
    String? purchaseOrderId,
    String? purchaseOrderNumber,
    required String createdBy,
    required this.createdAt,
    String? notes,
  }) : id = id.trim(),
       labId = labId.trim(),
       fundId = fundId.trim(),
       requirementId = requirementId.trim(),
       type = type.trim(),
       status = status.trim(),
       amount = _normalizedAmount(amount),
       itemNameSnapshot = itemNameSnapshot.trim(),
       fundNameSnapshot = _normalizedOptionalString(fundNameSnapshot),
       fundCodeSnapshot = _normalizedOptionalString(fundCodeSnapshot),
       purchaseOrderId = _normalizedOptionalString(purchaseOrderId),
       purchaseOrderNumber = _normalizedOptionalString(purchaseOrderNumber),
       createdBy = createdBy.trim(),
       notes = _normalizedOptionalString(notes);

  factory FundTransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return FundTransactionModel(
      id: doc.id,
      labId: (data['labId'] ?? '').toString(),
      fundId: (data['fundId'] ?? '').toString(),
      requirementId: (data['requirementId'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      amount: _doubleFromValue(data['amount']),
      itemNameSnapshot: (data['itemNameSnapshot'] ?? '').toString(),
      fundNameSnapshot: data['fundNameSnapshot']?.toString(),
      fundCodeSnapshot: data['fundCodeSnapshot']?.toString(),
      purchaseOrderId: data['purchaseOrderId']?.toString(),
      purchaseOrderNumber: data['purchaseOrderNumber']?.toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']),
      notes: data['notes']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'labId': labId,
      'fundId': fundId,
      'requirementId': requirementId,
      'type': type,
      'status': status,
      'amount': amount,
      'itemNameSnapshot': itemNameSnapshot,
      'fundNameSnapshot': fundNameSnapshot,
      'fundCodeSnapshot': fundCodeSnapshot,
      'purchaseOrderId': purchaseOrderId,
      'purchaseOrderNumber': purchaseOrderNumber,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'notes': notes,
    };
  }

  FundTransactionModel copyWith({
    String? id,
    String? labId,
    String? fundId,
    String? requirementId,
    String? type,
    String? status,
    double? amount,
    String? itemNameSnapshot,
    String? fundNameSnapshot,
    bool clearFundNameSnapshot = false,
    String? fundCodeSnapshot,
    bool clearFundCodeSnapshot = false,
    String? purchaseOrderId,
    bool clearPurchaseOrderId = false,
    String? purchaseOrderNumber,
    bool clearPurchaseOrderNumber = false,
    String? createdBy,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return FundTransactionModel(
      id: id ?? this.id,
      labId: labId ?? this.labId,
      fundId: fundId ?? this.fundId,
      requirementId: requirementId ?? this.requirementId,
      type: type ?? this.type,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      itemNameSnapshot: itemNameSnapshot ?? this.itemNameSnapshot,
      fundNameSnapshot: clearFundNameSnapshot
          ? null
          : (fundNameSnapshot ?? this.fundNameSnapshot),
      fundCodeSnapshot: clearFundCodeSnapshot
          ? null
          : (fundCodeSnapshot ?? this.fundCodeSnapshot),
      purchaseOrderId: clearPurchaseOrderId
          ? null
          : (purchaseOrderId ?? this.purchaseOrderId),
      purchaseOrderNumber: clearPurchaseOrderNumber
          ? null
          : (purchaseOrderNumber ?? this.purchaseOrderNumber),
      createdBy: createdBy ?? this.createdBy,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  bool get isAllocation => type.trim().toLowerCase() == typeAllocation;

  bool get isActive => status.trim().toLowerCase() == statusActive;

  bool get isPurchaseOrderTransaction {
    final purchaseOrderIdValue = purchaseOrderId?.trim() ?? '';
    return purchaseOrderIdValue.isNotEmpty;
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

  String get purchaseOrderDisplayLabel {
    final purchaseOrderNumberValue = purchaseOrderNumber?.trim() ?? '';
    if (purchaseOrderNumberValue.isNotEmpty) {
      return purchaseOrderNumberValue;
    }

    final purchaseOrderIdValue = purchaseOrderId?.trim() ?? '';
    if (purchaseOrderIdValue.isNotEmpty) {
      return purchaseOrderIdValue;
    }

    return '';
  }

  static String? _normalizedOptionalString(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static double _doubleFromValue(dynamic value) {
    if (value is num) {
      return _normalizedAmount(value.toDouble());
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return 0;
      }

      final parsed = double.tryParse(trimmed);
      if (parsed == null) {
        return 0;
      }

      return _normalizedAmount(parsed);
    }

    return 0;
  }

  static double _normalizedAmount(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return value;
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
