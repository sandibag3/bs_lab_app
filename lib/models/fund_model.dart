import 'package:cloud_firestore/cloud_firestore.dart';

class FundModel {
  static const String statusActive = 'active';
  static const String statusClosed = 'closed';
  static const String statusExpired = 'expired';
  static const List<String> allowedStoredStatuses = [
    statusActive,
    statusClosed,
  ];

  final String id;
  final String labId;
  final String fundName;
  final String? fundCode;
  final double totalAmount;
  final double availableAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
  final String status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FundModel({
    required String id,
    required String labId,
    required String fundName,
    String? fundCode,
    required this.totalAmount,
    required this.availableAmount,
    required this.startDate,
    required this.endDate,
    String? notes,
    required String status,
    required String createdBy,
    required this.createdAt,
    required this.updatedAt,
  }) : id = id.trim(),
       labId = labId.trim(),
       fundName = fundName.trim(),
       fundCode = _normalizedOptionalString(fundCode),
       notes = _normalizedOptionalString(notes),
       status = _readStoredStatus(status),
       createdBy = createdBy.trim();

  factory FundModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final fallbackDate = _dateOnly(DateTime.now());

    return FundModel(
      id: doc.id,
      labId: (data['labId'] ?? '').toString(),
      fundName: (data['fundName'] ?? '').toString(),
      fundCode: data['fundCode']?.toString(),
      totalAmount: _doubleFromValue(data['totalAmount']),
      availableAmount: _doubleFromValue(data['availableAmount']),
      startDate: _dateTimeFromValue(data['startDate']) ?? fallbackDate,
      endDate: _dateTimeFromValue(data['endDate']) ?? fallbackDate,
      notes: data['notes']?.toString(),
      status: data['status']?.toString() ?? statusActive,
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'labId': labId,
      'fundName': fundName,
      'fundCode': fundCode,
      'totalAmount': totalAmount,
      'availableAmount': availableAmount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'notes': notes,
      'status': status,
      'createdBy': createdBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  FundModel copyWith({
    String? id,
    String? labId,
    String? fundName,
    String? fundCode,
    bool clearFundCode = false,
    double? totalAmount,
    double? availableAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool clearNotes = false,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return FundModel(
      id: id ?? this.id,
      labId: labId ?? this.labId,
      fundName: fundName ?? this.fundName,
      fundCode: clearFundCode ? null : (fundCode ?? this.fundCode),
      totalAmount: totalAmount ?? this.totalAmount,
      availableAmount: availableAmount ?? this.availableAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }

  String get effectiveStatus {
    if (status == statusClosed) {
      return statusClosed;
    }

    final today = _dateOnly(DateTime.now());
    final fundEndDate = _dateOnly(endDate);
    if (fundEndDate.isBefore(today)) {
      return statusExpired;
    }

    return statusActive;
  }

  double get utilizedAmount {
    final value = totalAmount - availableAmount;
    return value < 0 ? 0 : value;
  }

  static String _readStoredStatus(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (allowedStoredStatuses.contains(normalized)) {
      return normalized;
    }
    return statusActive;
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
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value.trim()) ?? 0;
    }

    return 0;
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

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
