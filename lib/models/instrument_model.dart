import 'package:cloud_firestore/cloud_firestore.dart';

class InstrumentServiceHistoryRecord {
  final Timestamp? serviceDate;
  final String serviceDetails;
  final String serviceIncharge;
  final String serviceInchargeContactNo;
  final Timestamp createdAt;

  const InstrumentServiceHistoryRecord({
    required this.serviceDate,
    required this.serviceDetails,
    required this.serviceIncharge,
    required this.serviceInchargeContactNo,
    required this.createdAt,
  });

  factory InstrumentServiceHistoryRecord.fromMap(Map<String, dynamic> data) {
    return InstrumentServiceHistoryRecord(
      serviceDate: data['serviceDate'] is Timestamp
          ? data['serviceDate'] as Timestamp
          : null,
      serviceDetails: (data['serviceDetails'] ?? '').toString().trim(),
      serviceIncharge: (data['serviceIncharge'] ?? '').toString().trim(),
      serviceInchargeContactNo: (data['serviceInchargeContactNo'] ?? '')
          .toString()
          .trim(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceDate': serviceDate,
      'serviceDetails': serviceDetails,
      'serviceIncharge': serviceIncharge,
      'serviceInchargeContactNo': serviceInchargeContactNo,
      'createdAt': createdAt,
    };
  }
}

class InstrumentInchargeHistoryRecord {
  final String instrumentIncharge;
  final String instrumentInchargeContactNo;
  final Timestamp? tenureFrom;
  final Timestamp? tenureTo;
  final String notes;
  final Timestamp createdAt;

  const InstrumentInchargeHistoryRecord({
    required this.instrumentIncharge,
    required this.instrumentInchargeContactNo,
    required this.tenureFrom,
    required this.tenureTo,
    required this.notes,
    required this.createdAt,
  });

  factory InstrumentInchargeHistoryRecord.fromMap(Map<String, dynamic> data) {
    return InstrumentInchargeHistoryRecord(
      instrumentIncharge: (data['instrumentIncharge'] ?? '').toString().trim(),
      instrumentInchargeContactNo: (data['instrumentInchargeContactNo'] ?? '')
          .toString()
          .trim(),
      tenureFrom: data['tenureFrom'] is Timestamp
          ? data['tenureFrom'] as Timestamp
          : null,
      tenureTo: data['tenureTo'] is Timestamp
          ? data['tenureTo'] as Timestamp
          : null,
      notes: (data['notes'] ?? '').toString().trim(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'instrumentIncharge': instrumentIncharge,
      'instrumentInchargeContactNo': instrumentInchargeContactNo,
      'tenureFrom': tenureFrom,
      'tenureTo': tenureTo,
      'notes': notes,
      'createdAt': createdAt,
    };
  }
}

class InstrumentModel {
  static const List<String> categories = [
    'Weighing balance',
    'Magnetic stirrer',
    'Vacuum pump',
    'Rotary evaporator',
    'Chiller',
    'Heating mantel',
    'Refrigerator',
    'Oven',
    'Other',
  ];

  final String id;
  final String labId;
  final String name;
  final String category;
  final Timestamp? arrivedOn;
  final String brand;
  final String serialNo;
  final String catalogNumber;
  final String serviceIncharge;
  final String serviceInchargeContactNo;
  final String specification;
  final String userGuide;
  final String instrumentIncharge;
  final String instrumentInchargeContactNo;
  final Timestamp? instrumentInchargeTenureFrom;
  final Timestamp? instrumentInchargeTenureTo;
  final Timestamp? serviceDate;
  final String serviceDetails;
  final List<InstrumentServiceHistoryRecord> serviceHistory;
  final List<InstrumentInchargeHistoryRecord> inchargeHistory;
  final List<String> photoUrls;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  InstrumentModel({
    required this.id,
    required this.labId,
    required this.name,
    required this.category,
    required this.arrivedOn,
    required this.brand,
    required this.serialNo,
    required this.catalogNumber,
    required this.serviceIncharge,
    required this.serviceInchargeContactNo,
    required this.specification,
    required this.userGuide,
    required this.instrumentIncharge,
    required this.instrumentInchargeContactNo,
    required this.instrumentInchargeTenureFrom,
    required this.instrumentInchargeTenureTo,
    required this.serviceDate,
    required this.serviceDetails,
    required this.serviceHistory,
    required this.inchargeHistory,
    required this.photoUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InstrumentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return InstrumentModel(
      id: doc.id,
      labId: (data['labId'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      category: (data['category'] ?? '').toString().trim(),
      arrivedOn: data['arrivedOn'] is Timestamp
          ? data['arrivedOn'] as Timestamp
          : null,
      brand: (data['brand'] ?? '').toString().trim(),
      serialNo: (data['serialNo'] ?? '').toString().trim(),
      catalogNumber: (data['catalogNumber'] ?? '').toString().trim(),
      serviceIncharge: (data['serviceIncharge'] ?? '').toString().trim(),
      serviceInchargeContactNo: (data['serviceInchargeContactNo'] ?? '')
          .toString()
          .trim(),
      specification: (data['specification'] ?? '').toString().trim(),
      userGuide: (data['userGuide'] ?? '').toString().trim(),
      instrumentIncharge: (data['instrumentIncharge'] ?? '').toString().trim(),
      instrumentInchargeContactNo: (data['instrumentInchargeContactNo'] ?? '')
          .toString()
          .trim(),
      instrumentInchargeTenureFrom: data['instrumentInchargeTenureFrom'] is Timestamp
          ? data['instrumentInchargeTenureFrom'] as Timestamp
          : null,
      instrumentInchargeTenureTo: data['instrumentInchargeTenureTo'] is Timestamp
          ? data['instrumentInchargeTenureTo'] as Timestamp
          : null,
      serviceDate: data['serviceDate'] is Timestamp
          ? data['serviceDate'] as Timestamp
          : null,
      serviceDetails: (data['serviceDetails'] ?? '').toString().trim(),
      serviceHistory: _readServiceHistory(data['serviceHistory']),
      inchargeHistory: _readInchargeHistory(data['inchargeHistory']),
      photoUrls: _readPhotoUrls(data['photoUrls']),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  static List<String> _readPhotoUrls(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final single = (value ?? '').toString().trim();
    if (single.isEmpty) {
      return const [];
    }

    return [single];
  }

  static List<InstrumentServiceHistoryRecord> _readServiceHistory(dynamic value) {
    if (value is! Iterable) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) {
          return InstrumentServiceHistoryRecord.fromMap(
            Map<String, dynamic>.from(item),
          );
        })
        .toList();
  }

  static List<InstrumentInchargeHistoryRecord> _readInchargeHistory(dynamic value) {
    if (value is! Iterable) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) {
          return InstrumentInchargeHistoryRecord.fromMap(
            Map<String, dynamic>.from(item),
          );
        })
        .toList();
  }

  String get normalizedName => name.isEmpty ? 'Unnamed Instrument' : name;

  String get normalizedCategory {
    return categories.contains(category) ? category : 'Other';
  }

  String get previewPhoto {
    for (final photo in photoUrls) {
      final clean = photo.trim();
      if (clean.isNotEmpty) {
        return clean;
      }
    }

    return '';
  }

  InstrumentModel copyWith({
    String? id,
    String? labId,
    String? name,
    String? category,
    Timestamp? arrivedOn,
    bool clearArrivedOn = false,
    String? brand,
    String? serialNo,
    String? catalogNumber,
    String? serviceIncharge,
    String? serviceInchargeContactNo,
    String? specification,
    String? userGuide,
    String? instrumentIncharge,
    String? instrumentInchargeContactNo,
    Timestamp? instrumentInchargeTenureFrom,
    Timestamp? instrumentInchargeTenureTo,
    Timestamp? serviceDate,
    bool clearServiceDate = false,
    String? serviceDetails,
    List<InstrumentServiceHistoryRecord>? serviceHistory,
    List<InstrumentInchargeHistoryRecord>? inchargeHistory,
    List<String>? photoUrls,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return InstrumentModel(
      id: id ?? this.id,
      labId: labId ?? this.labId,
      name: name ?? this.name,
      category: category ?? this.category,
      arrivedOn: clearArrivedOn ? null : (arrivedOn ?? this.arrivedOn),
      brand: brand ?? this.brand,
      serialNo: serialNo ?? this.serialNo,
      catalogNumber: catalogNumber ?? this.catalogNumber,
      serviceIncharge: serviceIncharge ?? this.serviceIncharge,
      serviceInchargeContactNo:
          serviceInchargeContactNo ?? this.serviceInchargeContactNo,
      specification: specification ?? this.specification,
      userGuide: userGuide ?? this.userGuide,
      instrumentIncharge: instrumentIncharge ?? this.instrumentIncharge,
      instrumentInchargeContactNo:
          instrumentInchargeContactNo ?? this.instrumentInchargeContactNo,
      instrumentInchargeTenureFrom:
          instrumentInchargeTenureFrom ?? this.instrumentInchargeTenureFrom,
      instrumentInchargeTenureTo:
          instrumentInchargeTenureTo ?? this.instrumentInchargeTenureTo,
      serviceDate: clearServiceDate ? null : (serviceDate ?? this.serviceDate),
      serviceDetails: serviceDetails ?? this.serviceDetails,
      serviceHistory: serviceHistory ?? this.serviceHistory,
      inchargeHistory: inchargeHistory ?? this.inchargeHistory,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'labId': labId,
      'name': name,
      'category': category,
      'arrivedOn': arrivedOn,
      'brand': brand,
      'serialNo': serialNo,
      'catalogNumber': catalogNumber,
      'serviceIncharge': serviceIncharge,
      'serviceInchargeContactNo': serviceInchargeContactNo,
      'specification': specification,
      'userGuide': userGuide,
      'instrumentIncharge': instrumentIncharge,
      'instrumentInchargeContactNo': instrumentInchargeContactNo,
      'instrumentInchargeTenureFrom': instrumentInchargeTenureFrom,
      'instrumentInchargeTenureTo': instrumentInchargeTenureTo,
      'serviceDate': serviceDate,
      'serviceDetails': serviceDetails,
      'serviceHistory': serviceHistory.map((item) => item.toMap()).toList(),
      'inchargeHistory': inchargeHistory.map((item) => item.toMap()).toList(),
      'photoUrls': photoUrls,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
