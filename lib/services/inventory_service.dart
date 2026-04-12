import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chemical_model.dart';

class InventoryService {
  final CollectionReference inventoryRef =
      FirebaseFirestore.instance.collection('inventory');

  Stream<List<ChemicalModel>> getChemicals() {
    return inventoryRef.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ChemicalModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addChemical(ChemicalModel chemical) async {
    await inventoryRef.add(chemical.toMap());
  }

  Future<ChemicalModel?> findExistingByCas(String cas) async {
    final cleanCas = cas.trim();
    if (cleanCas.isEmpty) return null;

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .limit(10)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final chemicals = snapshot.docs
        .map((doc) => ChemicalModel.fromFirestore(doc))
        .toList();

    chemicals.sort((a, b) {
      if (a.isAvailable != b.isAvailable) {
        return a.isAvailable ? -1 : 1;
      }
      return a.label.compareTo(b.label);
    });

    return chemicals.first;
  }

  int carbonCountFromFormula(String formula) {
    final clean = formula.trim();
    if (clean.isEmpty) return 0;

    final match = RegExp(r'C(?![a-z])(\d*)').firstMatch(clean);
    if (match == null) return 0;

    final countText = match.group(1) ?? '';
    if (countText.isEmpty) return 1;

    return int.tryParse(countText) ?? 0;
  }

  Future<String> generateNextLabelFromFormula(String formula) async {
    final carbonCount = carbonCountFromFormula(formula);
    final prefix = 'C$carbonCount-';

    final snapshot = await inventoryRef.get();

    int maxSerial = 0;

    for (final doc in snapshot.docs) {
      final chemical = ChemicalModel.fromFirestore(doc);
      final label = chemical.label.trim();

      if (!label.startsWith(prefix)) continue;

      final match = RegExp(r'^C\d+-(\d+)$').firstMatch(label);
      if (match == null) continue;

      final serial = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (serial > maxSerial) {
        maxSerial = serial;
      }
    }

    return '$prefix${maxSerial + 1}';
  }
}