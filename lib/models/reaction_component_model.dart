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
  '\u00B5L',
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
  final String molecularWeight;
  final String amount;
  final String unit;
  final String density;
  final String volume;
  final String supplierOrSource;
  final String remarks;
  final bool isLimitingReagent;

  const ReactionComponentModel({
    required this.componentName,
    required this.role,
    required this.formulaOrNotes,
    required this.mmol,
    required this.equiv,
    required this.molecularWeight,
    required this.amount,
    required this.unit,
    required this.density,
    required this.volume,
    required this.supplierOrSource,
    required this.remarks,
    required this.isLimitingReagent,
  });

  factory ReactionComponentModel.fromMap(Map<String, dynamic> data) {
    final rawIsLimitingReagent = data['isLimitingReagent'];
    final isLimitingReagent = rawIsLimitingReagent is bool
        ? rawIsLimitingReagent
        : rawIsLimitingReagent.toString().trim().toLowerCase() == 'true';

    return ReactionComponentModel(
      componentName: (data['componentName'] ?? '').toString(),
      role: (data['role'] ?? '').toString(),
      formulaOrNotes: (data['formulaOrNotes'] ?? '').toString(),
      mmol: (data['mmol'] ?? '').toString(),
      equiv: (data['equiv'] ?? '').toString(),
      molecularWeight: (data['molecularWeight'] ?? '').toString(),
      amount: (data['amount'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      density: (data['density'] ?? '').toString(),
      volume: (data['volume'] ?? '').toString(),
      supplierOrSource: (data['supplierOrSource'] ?? '').toString(),
      remarks: (data['remarks'] ?? '').toString(),
      isLimitingReagent: isLimitingReagent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'componentName': componentName,
      'role': role,
      'formulaOrNotes': formulaOrNotes,
      'mmol': mmol,
      'equiv': equiv,
      'molecularWeight': molecularWeight,
      'amount': amount,
      'unit': unit,
      'density': density,
      'volume': volume,
      'supplierOrSource': supplierOrSource,
      'remarks': remarks,
      'isLimitingReagent': isLimitingReagent,
    };
  }
}
