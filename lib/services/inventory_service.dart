import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/chemical_model.dart';

class InventoryService {
  final CollectionReference inventoryRef =
      FirebaseFirestore.instance.collection('inventory');

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Stream<List<ChemicalModel>> getChemicals() {
    return inventoryRef.snapshots().map((snapshot) {
      return snapshot.docs
          .where(
            (doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>),
          )
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
    String? availability,
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
      'availability': availability,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> markOneBottleLowForCas({
    required String cas,
    required String labId,
  }) async {
    final cleanCas = cas.trim();
    final cleanLabId = labId.trim();

    if (cleanCas.isEmpty) {
      throw Exception('Chemical CAS is missing.');
    }

    if (cleanLabId.isEmpty) {
      throw Exception('No lab selected.');
    }

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .where('labId', isEqualTo: cleanLabId)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) {
      return false;
    }

    final docs = snapshot.docs.toList();
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aAvailability = (aData['availability'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final bAvailability = (bData['availability'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final aAvailable = aAvailability == 'available';
      final bAvailable = bAvailability == 'available';

      if (aAvailable != bAvailable) {
        return aAvailable ? -1 : 1;
      }

      final aLabel = (aData['label'] ?? '').toString().trim().toLowerCase();
      final bLabel = (bData['label'] ?? '').toString().trim().toLowerCase();
      return aLabel.compareTo(bLabel);
    });

    DocumentSnapshot? targetDoc;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final availability = (data['availability'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (availability == 'available') {
        targetDoc = doc;
        break;
      }
    }

    if (targetDoc == null) {
      return false;
    }

    await inventoryRef.doc(targetDoc.id).update({
      'availability': 'low',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<bool> markOneBottleFinishedForCas({
    required String cas,
    required String labId,
  }) async {
    final cleanCas = cas.trim();
    final cleanLabId = labId.trim();

    if (cleanCas.isEmpty) {
      throw Exception('Chemical CAS is missing.');
    }

    if (cleanLabId.isEmpty) {
      throw Exception('No lab selected.');
    }

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .where('labId', isEqualTo: cleanLabId)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) {
      return false;
    }

    final docs = snapshot.docs.toList();
    int availabilityPriority(Map<String, dynamic> data) {
      final availability = (data['availability'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (availability == 'low') return 0;
      if (availability == 'available') return 1;
      return 2;
    }

    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final priorityComparison = availabilityPriority(
        aData,
      ).compareTo(availabilityPriority(bData));
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      final aLabel = (aData['label'] ?? '').toString().trim().toLowerCase();
      final bLabel = (bData['label'] ?? '').toString().trim().toLowerCase();
      return aLabel.compareTo(bLabel);
    });

    DocumentSnapshot? targetDoc;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final priority = availabilityPriority(data);
      if (priority < 2) {
        targetDoc = doc;
        break;
      }
    }

    if (targetDoc == null) {
      return false;
    }

    await inventoryRef.doc(targetDoc.id).update({
      'availability': 'finished',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<List<ChemicalModel>> getActiveBottlesForCas({
    required String cas,
    required String labId,
  }) async {
    final cleanCas = cas.trim();
    final cleanLabId = labId.trim();

    if (cleanCas.isEmpty) {
      throw Exception('Chemical CAS is missing.');
    }

    if (cleanLabId.isEmpty) {
      throw Exception('No lab selected.');
    }

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .where('labId', isEqualTo: cleanLabId)
        .limit(50)
        .get();

    final bottles = snapshot.docs
        .map((doc) => ChemicalModel.fromFirestore(doc))
        .where((chemical) {
          final availability = chemical.availability.trim().toLowerCase();
          return availability == 'available' || availability == 'low';
        })
        .toList();

    int availabilityPriority(ChemicalModel chemical) {
      final availability = chemical.availability.trim().toLowerCase();
      if (availability == 'low') return 0;
      if (availability == 'available') return 1;
      return 2;
    }

    bottles.sort((a, b) {
      final priorityComparison = availabilityPriority(
        a,
      ).compareTo(availabilityPriority(b));
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      return a.label.trim().toLowerCase().compareTo(
        b.label.trim().toLowerCase(),
      );
    });

    return bottles;
  }

  Future<void> markBottleFinishedById({
    required String docId,
  }) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) {
      throw Exception('Bottle id is missing.');
    }

    await inventoryRef.doc(cleanDocId).update({
      'availability': 'finished',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ChemicalModel?> findExistingByCas(String cas) async {
    final cleanCas = cas.trim();
    if (cleanCas.isEmpty) return null;

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final chemicals = snapshot.docs
        .where(
          (doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>),
        )
        .map((doc) => ChemicalModel.fromFirestore(doc))
        .toList();

    if (chemicals.isEmpty) return null;

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
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final docs = snapshot.docs
        .where(
          (doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>),
        )
        .toList();

    if (docs.isEmpty) return null;

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

  Future<List<ChemicalModel>> getBottlesByCas(String cas) async {
    final cleanCas = cas.trim();
    if (cleanCas.isEmpty) return [];

    final snapshot = await inventoryRef
        .where('cas', isEqualTo: cleanCas)
        .get();

    final bottles = snapshot.docs
        .where(
          (doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>),
        )
        .map((doc) => ChemicalModel.fromFirestore(doc))
        .toList();

    bottles.sort((a, b) {
      if (a.isAvailable != b.isAvailable) {
        return a.isAvailable ? -1 : 1;
      }
      return a.label.compareTo(b.label);
    });

    return bottles;
  }

  Future<int> getBottleCountByCas(String cas) async {
    final bottles = await getBottlesByCas(cas);
    return bottles.length;
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
      if (!_matchesCurrentLab(data)) continue;
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

  Future<String> generateNextLabel({
    required String category,
    String? subcategory,
    String? formula,
    String? catalystMetal,
  }) async {
    final prefix = getPrefix(
      category: category,
      subcategory: subcategory,
      formula: formula,
      catalystMetal: catalystMetal,
    );

    if (prefix == null || prefix.isEmpty) {
      return 'Could not auto-generate';
    }

    return generateNextLabelByPrefix(prefix);
  }

  String? getPrefix({
    required String category,
    String? subcategory,
    String? formula,
    String? catalystMetal,
  }) {
    final c = category.trim().toLowerCase();
    final s = subcategory?.trim().toLowerCase();

    if (c == 'acid') return 'A';

    if (c == 'base') {
      if (s == 'organic') return 'OB';
      if (s == 'inorganic') return 'IB';
      return 'B';
    }

    if (c == 'salt') return 'S';

    if (c == 'metal') return 'M';

    if (c == 'catalyst') {
      final metal = catalystMetal?.trim();
      if (metal != null && metal.isNotEmpty) {
        return _normalizeMetalPrefix(metal);
      }
      return 'CAT';
    }

    if (c == 'ligand') {
      if (s == 'phosphine') return 'Phos';
      if (s == 'n-donor' || s == 'nitrogen donor') return 'ND';
      return 'L';
    }

    if (c == 'general') {
      final count = carbonCountFromFormula(formula ?? '');
      if (count > 0) return 'C$count';
      return null;
    }

    return null;
  }

  String _normalizeMetalPrefix(String metal) {
    final value = metal.trim();
    if (value.isEmpty) return 'CAT';

    if (value.length == 1) return value.toUpperCase();

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

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
