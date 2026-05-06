import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String specification;
  final String userGuide;
  final String instrumentIncharge;
  final Timestamp? serviceDate;
  final String serviceDetails;
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
    required this.specification,
    required this.userGuide,
    required this.instrumentIncharge,
    required this.serviceDate,
    required this.serviceDetails,
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
      specification: (data['specification'] ?? '').toString().trim(),
      userGuide: (data['userGuide'] ?? '').toString().trim(),
      instrumentIncharge: (data['instrumentIncharge'] ?? '').toString().trim(),
      serviceDate: data['serviceDate'] is Timestamp
          ? data['serviceDate'] as Timestamp
          : null,
      serviceDetails: (data['serviceDetails'] ?? '').toString().trim(),
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
    String? specification,
    String? userGuide,
    String? instrumentIncharge,
    Timestamp? serviceDate,
    bool clearServiceDate = false,
    String? serviceDetails,
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
      specification: specification ?? this.specification,
      userGuide: userGuide ?? this.userGuide,
      instrumentIncharge: instrumentIncharge ?? this.instrumentIncharge,
      serviceDate: clearServiceDate ? null : (serviceDate ?? this.serviceDate),
      serviceDetails: serviceDetails ?? this.serviceDetails,
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
      'specification': specification,
      'userGuide': userGuide,
      'instrumentIncharge': instrumentIncharge,
      'serviceDate': serviceDate,
      'serviceDetails': serviceDetails,
      'photoUrls': photoUrls,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
