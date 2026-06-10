import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderModel {
  static const double _amountEpsilon = 0.000001;

  final String id;
  final String labId;

  final String folderNumber;
  final String? institutePoNumber;
  final String? indentNumber;
  final String? title;

  final String fundId;
  final String fundNameSnapshot;
  final String? fundCodeSnapshot;

  final List<String> orderIds;
  final int orderCount;

  final double estimatedTotal;
  final double allocatedTotal;

  final double? actualTotal;
  final double? reconciledDeltaAmount;

  final String status;

  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? actualCostRecordedBy;
  final DateTime? actualCostRecordedAt;

  final bool costReconciled;
  final String? costReconciledBy;
  final DateTime? costReconciledAt;
  final String? fundTransactionId;

  final String? vendor;
  final String? modeOfPurchase;
  final String? notes;

  PurchaseOrderModel({
    required String id,
    required String labId,
    required String folderNumber,
    String? institutePoNumber,
    String? indentNumber,
    String? title,
    required String fundId,
    required String fundNameSnapshot,
    String? fundCodeSnapshot,
    required List<String> orderIds,
    required int orderCount,
    required double estimatedTotal,
    required double allocatedTotal,
    double? actualTotal,
    double? reconciledDeltaAmount,
    required String status,
    required String createdBy,
    this.createdAt,
    this.updatedAt,
    String? actualCostRecordedBy,
    this.actualCostRecordedAt,
    this.costReconciled = false,
    String? costReconciledBy,
    this.costReconciledAt,
    String? fundTransactionId,
    String? vendor,
    String? modeOfPurchase,
    String? notes,
  }) : id = id.trim(),
       labId = labId.trim(),
       folderNumber = folderNumber.trim(),
       institutePoNumber = _normalizedOptionalString(institutePoNumber),
       indentNumber = _normalizedOptionalString(indentNumber),
       title = _normalizedOptionalString(title),
       fundId = fundId.trim(),
       fundNameSnapshot = fundNameSnapshot.trim(),
       fundCodeSnapshot = _normalizedOptionalString(fundCodeSnapshot),
       orderIds = List.unmodifiable(_sanitizeOrderIds(orderIds)),
       orderCount = orderCount < 0 ? 0 : orderCount,
       estimatedTotal = _finiteDoubleOrZero(estimatedTotal),
       allocatedTotal = _finiteDoubleOrZero(allocatedTotal),
       actualTotal = _finiteNullableDouble(actualTotal),
       reconciledDeltaAmount = _finiteNullableDouble(reconciledDeltaAmount),
       status = status.trim(),
       createdBy = createdBy.trim(),
       actualCostRecordedBy = _normalizedOptionalString(actualCostRecordedBy),
       costReconciledBy = _normalizedOptionalString(costReconciledBy),
       fundTransactionId = _normalizedOptionalString(fundTransactionId),
       vendor = _normalizedOptionalString(vendor),
       modeOfPurchase = _normalizedOptionalString(modeOfPurchase),
       notes = _normalizedOptionalString(notes);

  factory PurchaseOrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final parsedOrderIds = _orderIdsFromValue(data['orderIds']);
    final parsedOrderCount = _intFromValue(data['orderCount']);

    return PurchaseOrderModel(
      id: doc.id,
      labId: _requiredStringFromValue(data['labId']),
      folderNumber: _requiredStringFromValue(data['folderNumber']),
      institutePoNumber: data['institutePoNumber'],
      indentNumber: data['indentNumber'],
      title: data['title'],
      fundId: _requiredStringFromValue(data['fundId']),
      fundNameSnapshot: _requiredStringFromValue(data['fundNameSnapshot']),
      fundCodeSnapshot: data['fundCodeSnapshot'],
      orderIds: parsedOrderIds,
      orderCount: parsedOrderCount != null && parsedOrderCount >= 0
          ? parsedOrderCount
          : parsedOrderIds.length,
      estimatedTotal: _doubleFromValue(data['estimatedTotal']) ?? 0.0,
      allocatedTotal: _doubleFromValue(data['allocatedTotal']) ?? 0.0,
      actualTotal: _doubleFromValue(data['actualTotal']),
      reconciledDeltaAmount: _doubleFromValue(data['reconciledDeltaAmount']),
      status: _requiredStringFromValue(data['status']),
      createdBy: _requiredStringFromValue(data['createdBy']),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
      actualCostRecordedBy: data['actualCostRecordedBy'],
      actualCostRecordedAt: _dateTimeFromValue(data['actualCostRecordedAt']),
      costReconciled: _boolFromValue(data['costReconciled']),
      costReconciledBy: data['costReconciledBy'],
      costReconciledAt: _dateTimeFromValue(data['costReconciledAt']),
      fundTransactionId: data['fundTransactionId'],
      vendor: data['vendor'],
      modeOfPurchase: data['modeOfPurchase'],
      notes: data['notes'],
    );
  }

  bool get hasInstitutePoNumber {
    final cleanInstitutePoNumber = institutePoNumber?.trim() ?? '';
    return cleanInstitutePoNumber.isNotEmpty;
  }

  bool get hasActualCost => actualTotal != null;

  bool get hasFundReconciliation {
    final cleanTransactionId = fundTransactionId?.trim() ?? '';
    return costReconciled && cleanTransactionId.isNotEmpty;
  }

  String get displayNumber {
    final cleanInstitutePoNumber = institutePoNumber?.trim() ?? '';
    if (cleanInstitutePoNumber.isNotEmpty) {
      return cleanInstitutePoNumber;
    }

    final cleanFolderNumber = folderNumber.trim();
    if (cleanFolderNumber.isNotEmpty) {
      return cleanFolderNumber;
    }

    return id;
  }

  double get savingsAmount {
    final currentActualTotal = actualTotal;
    if (currentActualTotal == null) {
      return 0.0;
    }

    final difference = allocatedTotal - currentActualTotal;
    if (difference <= 0) {
      return 0.0;
    }

    return _clampTinyAmount(difference);
  }

  double get additionalExpenditure {
    final currentActualTotal = actualTotal;
    if (currentActualTotal == null) {
      return 0.0;
    }

    final difference = currentActualTotal - allocatedTotal;
    if (difference <= 0) {
      return 0.0;
    }

    return _clampTinyAmount(difference);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'labId': labId,
      'folderNumber': folderNumber,
      'institutePoNumber': institutePoNumber,
      'indentNumber': indentNumber,
      'title': title,
      'fundId': fundId,
      'fundNameSnapshot': fundNameSnapshot,
      'fundCodeSnapshot': fundCodeSnapshot,
      'orderIds': List<String>.from(orderIds),
      'orderCount': orderCount,
      'estimatedTotal': estimatedTotal,
      'allocatedTotal': allocatedTotal,
      'actualTotal': actualTotal,
      'reconciledDeltaAmount': reconciledDeltaAmount,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'actualCostRecordedBy': actualCostRecordedBy,
      'actualCostRecordedAt': actualCostRecordedAt != null
          ? Timestamp.fromDate(actualCostRecordedAt!)
          : null,
      'costReconciled': costReconciled,
      'costReconciledBy': costReconciledBy,
      'costReconciledAt': costReconciledAt != null
          ? Timestamp.fromDate(costReconciledAt!)
          : null,
      'fundTransactionId': fundTransactionId,
      'vendor': vendor,
      'modeOfPurchase': modeOfPurchase,
      'notes': notes,
    };
  }

  PurchaseOrderModel copyWith({
    String? id,
    String? labId,
    String? folderNumber,
    String? institutePoNumber,
    bool clearInstitutePoNumber = false,
    String? indentNumber,
    bool clearIndentNumber = false,
    String? title,
    bool clearTitle = false,
    String? fundId,
    String? fundNameSnapshot,
    String? fundCodeSnapshot,
    bool clearFundCodeSnapshot = false,
    List<String>? orderIds,
    int? orderCount,
    double? estimatedTotal,
    double? allocatedTotal,
    double? actualTotal,
    bool clearActualTotal = false,
    double? reconciledDeltaAmount,
    bool clearReconciledDeltaAmount = false,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    String? actualCostRecordedBy,
    bool clearActualCostRecordedBy = false,
    DateTime? actualCostRecordedAt,
    bool clearActualCostRecordedAt = false,
    bool? costReconciled,
    String? costReconciledBy,
    bool clearCostReconciledBy = false,
    DateTime? costReconciledAt,
    bool clearCostReconciledAt = false,
    String? fundTransactionId,
    bool clearFundTransactionId = false,
    String? vendor,
    bool clearVendor = false,
    String? modeOfPurchase,
    bool clearModeOfPurchase = false,
    String? notes,
    bool clearNotes = false,
  }) {
    final nextOrderIds = orderIds == null
        ? this.orderIds
        : _sanitizeOrderIds(orderIds);
    final nextOrderCount = orderCount ??
        (orderIds != null ? nextOrderIds.length : this.orderCount);

    return PurchaseOrderModel(
      id: id ?? this.id,
      labId: labId ?? this.labId,
      folderNumber: folderNumber ?? this.folderNumber,
      institutePoNumber: clearInstitutePoNumber
          ? null
          : (institutePoNumber ?? this.institutePoNumber),
      indentNumber: clearIndentNumber
          ? null
          : (indentNumber ?? this.indentNumber),
      title: clearTitle ? null : (title ?? this.title),
      fundId: fundId ?? this.fundId,
      fundNameSnapshot: fundNameSnapshot ?? this.fundNameSnapshot,
      fundCodeSnapshot: clearFundCodeSnapshot
          ? null
          : (fundCodeSnapshot ?? this.fundCodeSnapshot),
      orderIds: nextOrderIds,
      orderCount: nextOrderCount,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      allocatedTotal: allocatedTotal ?? this.allocatedTotal,
      actualTotal: clearActualTotal ? null : (actualTotal ?? this.actualTotal),
      reconciledDeltaAmount: clearReconciledDeltaAmount
          ? null
          : (reconciledDeltaAmount ?? this.reconciledDeltaAmount),
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      actualCostRecordedBy: clearActualCostRecordedBy
          ? null
          : (actualCostRecordedBy ?? this.actualCostRecordedBy),
      actualCostRecordedAt: clearActualCostRecordedAt
          ? null
          : (actualCostRecordedAt ?? this.actualCostRecordedAt),
      costReconciled: costReconciled ?? this.costReconciled,
      costReconciledBy: clearCostReconciledBy
          ? null
          : (costReconciledBy ?? this.costReconciledBy),
      costReconciledAt: clearCostReconciledAt
          ? null
          : (costReconciledAt ?? this.costReconciledAt),
      fundTransactionId: clearFundTransactionId
          ? null
          : (fundTransactionId ?? this.fundTransactionId),
      vendor: clearVendor ? null : (vendor ?? this.vendor),
      modeOfPurchase: clearModeOfPurchase
          ? null
          : (modeOfPurchase ?? this.modeOfPurchase),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  static String _requiredStringFromValue(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String? _normalizedOptionalString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  static List<String> _orderIdsFromValue(Object? value) {
    if (value is! List) {
      return <String>[];
    }

    final normalized = <String>[];
    for (final entry in value) {
      if (entry is! String) {
        continue;
      }

      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      normalized.add(trimmed);
    }

    return normalized;
  }

  static List<String> _sanitizeOrderIds(Iterable<String> values) {
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      normalized.add(trimmed);
    }

    return normalized;
  }

  static int? _intFromValue(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      if (!value.isFinite) {
        return null;
      }

      return value.toInt();
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      final parsedInt = int.tryParse(trimmed);
      if (parsedInt != null) {
        return parsedInt;
      }

      final parsedDouble = double.tryParse(trimmed);
      if (parsedDouble == null || !parsedDouble.isFinite) {
        return null;
      }

      return parsedDouble.toInt();
    }

    return null;
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

  static double _finiteDoubleOrZero(double value) {
    return value.isFinite ? value : 0.0;
  }

  static double? _finiteNullableDouble(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }

    return value;
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

  static double _clampTinyAmount(double value) {
    if (value.abs() < _amountEpsilon) {
      return 0.0;
    }

    return value;
  }
}
