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
    await inventoryRef.add({
      ...chemical.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 🔥 NEW FUNCTION (THIS WAS MISSING)
  Map<String, List<ChemicalModel>> groupByCas(List<ChemicalModel> chemicals) {
    final Map<String, List<ChemicalModel>> grouped = {};

    for (final chem in chemicals) {
      final key = chem.cas.trim().isEmpty
          ? 'name:${chem.chemicalName.toLowerCase()}'
          : chem.cas.trim().toLowerCase();

      grouped.putIfAbsent(key, () => []).add(chem);
    }

    return grouped;
  }

  Future<void> updateChemicalStock({
    required String docId,
    required String quantity,
    String? brand,
    String? catNumber,
    String? arrivalDate,
    String? orderedBy,
    String? location,
    String? texture,
    String? functionalGroups,
  }) async {
    await inventoryRef.doc(docId).update({
      'quantity': quantity,
      'brand': brand,
      'catNumber': catNumber,
      'arrivalDate': arrivalDate,
      'orderedBy': orderedBy,
      'location': location,
      'texture': texture,
      'functionalGroups': functionalGroups,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ChemicalModel?> findExistingByCas(String cas) async {
    final cleanCas = cas.trim();
    if (cleanCas.isEmpty) return null;

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .limit(20)
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

  Future<DocumentSnapshot?> findExistingDocByCas(String cas) async {
    final cleanCas = cas.trim();
    if (cleanCas.isEmpty) return null;

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .limit(20)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final docs = snapshot.docs.toList();

    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aAvailability = (aData['availability'] ?? '').toString();
      final bAvailability = (bData['availability'] ?? '').toString();

      final aAvailable = aAvailability.toLowerCase() == 'available';
      final bAvailable = bAvailability.toLowerCase() == 'available';

      if (aAvailable != bAvailable) {
        return aAvailable ? -1 : 1;
      }

      final aLabel = (aData['label'] ?? '').toString();
      final bLabel = (bData['label'] ?? '').toString();
      return aLabel.compareTo(bLabel);
    });

    return docs.first;
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
    if (carbonCount <= 0) return 'Could not auto-generate';

    return generateNextLabelByPrefix('C$carbonCount');
  }

  Future<String> generateNextLabelByPrefix(String prefix) async {
    final cleanPrefix = prefix.trim();
    if (cleanPrefix.isEmpty) return 'Could not auto-generate';

    final snapshot = await inventoryRef.get();

    int maxSerial = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final label = (data['label'] ?? '').toString().trim();

      if (!label.startsWith('$cleanPrefix-')) continue;

      final match = RegExp('^${RegExp.escape(cleanPrefix)}-(\\d+)\$')
          .firstMatch(label);

      if (match == null) continue;

      final serial = int.tryParse(match.group(1) ?? '0') ?? 0;
      if (serial > maxSerial) {
        maxSerial = serial;
      }
    }

    return '$cleanPrefix-${maxSerial + 1}';
  }

  // ===== OPTIONS =====

  List<String> locationOptions = const [
    'Yellow Cab',
    'Acid Cabinet',
    'Base Cabinet',
    'Solvent Rack',
    'Dry Solvent Rack',
    'Deuterated Solvent Rack',
    'Refrigerator',
    'Freezer 1A',
    'Freezer 1B',
    'Freezer 1C',
    'Freezer 1D',
    'Freezer 1E',
    'Desiccator',
    'Glovebox',
    'Drawer 1',
    'Drawer 2',
    'Drawer 3',
    'Other',
  ];

  List<String> textureOptions = const [
    'Solid',
    'Liquid',
    'Oil',
    'Powder',
    'Crystals',
    'Solution',
    'Suspension',
    'Gas',
    'Paste',
    'Other',
  ];

  List<String> functionalGroupOptions = const [
    'Alcohol',
    'Aldehyde',
    'Ketone',
    'Ester',
    'Amide',
    'Amine',
    'Carboxylic Acid',
    'Halide',
    'Nitrile',
    'Nitro',
    'Ether',
    'Thioether',
    'Phosphine',
    'Pyridine',
    'Imine',
    'Alkene',
    'Alkyne',
    'Arene',
    'Heteroarene',
    'Boronic Acid',
    'Sulfonamide',
    'Peroxide',
    'Carbonate',
    'Hydride',
    'Other',
  ];
}