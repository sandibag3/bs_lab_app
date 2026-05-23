const List<String> reactionComponentRoles = [
  'Starting material',
  'Reagent',
  'Catalyst',
  'Ligand',
  'Solvent',
  'Additive',
  'Product',
  'Other',
];

const List<String> reactionComponentUnits = [
  'mg',
  'g',
  'µL',
  'mL',
  'mmol',
  'equiv',
  'mol%',
  'wt%',
];

class ReactionComponentModel {
  final String componentName;
  final String role;
  final String formulaOrNotes;
  final String mmol;
  final String equiv;
  final String amount;
  final String unit;
  final String supplierOrSource;
  final String remarks;

  const ReactionComponentModel({
    required this.componentName,
    required this.role,
    required this.formulaOrNotes,
    required this.mmol,
    required this.equiv,
    required this.amount,
    required this.unit,
    required this.supplierOrSource,
    required this.remarks,
  });

  factory ReactionComponentModel.fromMap(Map<String, dynamic> data) {
    return ReactionComponentModel(
      componentName: (data['componentName'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      formulaOrNotes: (data['formulaOrNotes'] ?? '').toString(),
      mmol: (data['mmol'] ?? '').toString(),
      equiv: (data['equiv'] ?? '').toString(),
      amount: (data['amount'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      supplierOrSource: (data['supplierOrSource'] ?? '').toString(),
      remarks: (data['remarks'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'componentName': componentName,
      'role': role,
      'formulaOrNotes': formulaOrNotes,
      'mmol': mmol,
      'equiv': equiv,
      'amount': amount,
      'unit': unit,
      'supplierOrSource': supplierOrSource,
      'remarks': remarks,
    };
  }
}
