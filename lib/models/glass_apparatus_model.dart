import 'package:cloud_firestore/cloud_firestore.dart';

class GlassApparatusModel {
  static const List<String> categories = [
    'Beakers',
    'Conical flasks',
    'Round-bottom flasks',
    'Measuring cylinders',
    'Pipettes',
    'Burettes',
    'Condensers',
    'Funnels',
    'Separating funnels',
    'Test tubes',
    'Watch glasses',
    'Desiccators',
    'Adapters and joints',
    'Other',
  ];

  static const List<String> conditionOptions = [
    'Available',
    'Limited',
    'Damaged',
    'Missing',
  ];

  final String id;
  final String labId;
  final String name;
  final String category;
  final String size;
  final int quantity;
  final String condition;
  final String location;
  final String incharge;
  final String notes;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const GlassApparatusModel({
    required this.id,
    required this.labId,
    required this.name,
    required this.category,
    required this.size,
    required this.quantity,
    required this.condition,
    required this.location,
    required this.incharge,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GlassApparatusModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return GlassApparatusModel(
      id: doc.id,
      labId: (data['labId'] ?? '').toString().trim(),
      name: (data['name'] ?? '').toString().trim(),
      category: (data['category'] ?? '').toString().trim(),
      size: (data['size'] ?? '').toString().trim(),
      quantity: _readQuantity(data['quantity']),
      condition: _readCondition(data['condition']),
      location: (data['location'] ?? '').toString().trim(),
      incharge: (data['incharge'] ?? '').toString().trim(),
      notes: (data['notes'] ?? '').toString().trim(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  static int _readQuantity(dynamic value) {
    if (value is int) {
      return value < 0 ? 0 : value;
    }

    if (value is num) {
      final parsed = value.round();
      return parsed < 0 ? 0 : parsed;
    }

    final parsed = int.tryParse((value ?? '').toString().trim());
    if (parsed == null || parsed < 0) {
      return 0;
    }

    return parsed;
  }

  static String _readCondition(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (conditionOptions.contains(raw)) {
      return raw;
    }

    return conditionOptions.first;
  }

  String get normalizedName => name.isEmpty ? 'Unnamed apparatus' : name;

  String get normalizedCategory {
    return categories.contains(category) ? category : 'Other';
  }

  String get normalizedCondition {
    return conditionOptions.contains(condition)
        ? condition
        : conditionOptions.first;
  }

  String get displaySize => size.isEmpty ? 'Size not set' : size;

  Map<String, dynamic> toMap() {
    return {
      'labId': labId,
      'name': name,
      'category': normalizedCategory,
      'size': size,
      'quantity': quantity,
      'condition': normalizedCondition,
      'location': location,
      'incharge': incharge,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
