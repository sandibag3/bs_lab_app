import 'package:cloud_firestore/cloud_firestore.dart';

class ChemicalModel {
  final String id;
  final String labId;
  final String label;
  final String chemicalName;
  final String cas;
  final String formula;
  final String molWt;
  final String availability;
  final String texture;
  final String location;
  final String quantity;
  final String bottleSize;
  final String bottleUnit;
  final String brand;
  final String vendor;
  final String catNumber;
  final String arrivalDate;
  final String orderedBy;
  final String functionalGroups;
  final String sheetTab;
  final bool isActiveBottle;

  ChemicalModel({
    required this.id,
    required this.labId,
    required this.label,
    required this.chemicalName,
    required this.cas,
    required this.formula,
    required this.molWt,
    required this.availability,
    required this.texture,
    required this.location,
    required this.quantity,
    this.bottleSize = '',
    this.bottleUnit = '',
    required this.brand,
    required this.vendor,
    required this.catNumber,
    required this.arrivalDate,
    required this.orderedBy,
    required this.functionalGroups,
    required this.sheetTab,
    this.isActiveBottle = false,
  });

  factory ChemicalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ChemicalModel(
      id: doc.id,
      labId: data['labId'] ?? '',
      label: data['label'] ?? '',
      chemicalName: data['chemicalName'] ?? '',
      cas: data['cas'] ?? '',
      formula: data['formula'] ?? '',
      molWt: data['molWt'] ?? '',
      availability: data['availability'] ?? '',
      texture: data['texture'] ?? '',
      location: data['location'] ?? '',
      quantity: data['quantity'] ?? '',
      bottleSize: data['bottleSize'] ?? '',
      bottleUnit: data['bottleUnit'] ?? '',
      brand: data['brand'] ?? '',
      vendor: data['vendor'] ?? '',
      catNumber: data['catNumber'] ?? '',
      arrivalDate: data['arrivalDate'] ?? '',
      orderedBy: data['orderedBy'] ?? '',
      functionalGroups: data['functionalGroups'] ?? '',
      sheetTab: data['sheetTab'] ?? '',
      isActiveBottle: data['isActiveBottle'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'labId': labId,
      'label': label,
      'chemicalName': chemicalName,
      'cas': cas,
      'formula': formula,
      'molWt': molWt,
      'availability': availability,
      'texture': texture,
      'location': location,
      'quantity': quantity,
      'bottleSize': bottleSize,
      'bottleUnit': bottleUnit,
      'brand': brand,
      'vendor': vendor,
      'catNumber': catNumber,
      'arrivalDate': arrivalDate,
      'orderedBy': orderedBy,
      'functionalGroups': functionalGroups,
      'sheetTab': sheetTab,
      'isActiveBottle': isActiveBottle,
    };
  }

  bool get isFinished {
    final value = availability.toLowerCase().trim();
    return value.contains('finished') ||
        value.contains('empty') ||
        value.contains('not available') ||
        value == 'nil' ||
        value == '0';
  }

  bool get isAvailable => !isFinished;

  String get normalizedCas => cas.trim().toLowerCase();
  String get normalizedName => chemicalName.trim().toLowerCase();
}
