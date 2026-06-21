import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/chemical_model.dart';
import 'firestore_access_guard.dart';
import 'order_service.dart';

class InventoryService {
  final CollectionReference inventoryRef = FirebaseFirestore.instance
      .collection('inventory');

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _inventorySnapshots() {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    if (appState.isDemoLabSelected) {
      return FirebaseFirestore.instance.collection('inventory').snapshots();
    }

    return FirebaseFirestore.instance
        .collection('inventory')
        .where('labId', isEqualTo: selectedLabId)
        .snapshots();
  }

  Stream<List<ChemicalModel>> getChemicals() {
    return FirestoreAccessGuard.guardLabStream<List<ChemicalModel>>(
      source: _inventorySnapshots(),
      emptyValue: <ChemicalModel>[],
      onData: (snapshot) {
        final docs = AppState.instance.isDemoLabSelected
            ? snapshot.docs.where((doc) => _matchesCurrentLab(doc.data()))
            : snapshot.docs;

        return docs.map((doc) => ChemicalModel.fromFirestore(doc)).toList();
      },
    );
  }

  Future<List<ChemicalModel>> getChemicalsOnce() async {
    if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
      return <ChemicalModel>[];
    }

    try {
      final appState = AppState.instance;
      final selectedLabId = appState.selectedLabId.trim();
      final snapshot = appState.isDemoLabSelected
          ? await inventoryRef.get()
          : await inventoryRef.where('labId', isEqualTo: selectedLabId).get();

      final docs = appState.isDemoLabSelected
          ? snapshot.docs.where(
              (doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>),
            )
          : snapshot.docs;

      return docs.map((doc) => ChemicalModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (error) {
      if (FirestoreAccessGuard.isPermissionDenied(error)) {
        throw const LabDataAccessException();
      }
      rethrow;
    }
  }

  Future<void> addChemical(ChemicalModel chemical) async {
    await inventoryRef.add({
      ...chemical.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> addChemicalFromDeliveredOrder({
    required ChemicalModel chemical,
    required String orderId,
    String? inventoryAddedBy,
  }) async {
    final cleanOrderId = orderId.trim();
    if (cleanOrderId.isEmpty) {
      throw Exception('Order id is missing.');
    }

    final firestore = FirebaseFirestore.instance;
    final orderRef = firestore.collection('orders').doc(cleanOrderId);
    final chemicalRef = inventoryRef.doc();

    await firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      final orderData = orderSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw const OrderInventoryException('Order no longer exists.');
      }

      final status = (orderData['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (status != 'delivered') {
        throw const OrderInventoryException(
          'This order can no longer be added to inventory because its status has changed.',
        );
      }

      if (orderData['inventoryAdded'] == true) {
        throw const OrderInventoryException(
          'This order has already been added to inventory.',
        );
      }

      final serverTimestamp = FieldValue.serverTimestamp();
      final orderUpdates = <String, dynamic>{
        'inventoryAdded': true,
        'inventoryAddedAt': serverTimestamp,
        'inventoryRecordId': chemicalRef.id,
      };
      final cleanInventoryAddedBy = inventoryAddedBy?.trim() ?? '';
      if (cleanInventoryAddedBy.isNotEmpty) {
        orderUpdates['inventoryAddedBy'] = cleanInventoryAddedBy;
      }

      transaction.set(chemicalRef, {
        ...chemical.toMap(),
        'createdAt': serverTimestamp,
        'updatedAt': serverTimestamp,
      });
      transaction.update(orderRef, orderUpdates);
    });

    return chemicalRef.id;
  }

  String _normalizedLabel(String label) => label.trim().toUpperCase();

  Future<String?> getExistingLabelForCas({
    required String labId,
    required String cas,
    String? excludeDocId,
  }) async {
    final cleanLabId = labId.trim();
    final cleanCas = cas.trim();
    final cleanExcludeId = excludeDocId?.trim() ?? '';

    if (cleanLabId.isEmpty || cleanCas.isEmpty) {
      return null;
    }

    final snapshot = await inventoryRef
        .where('labId', isEqualTo: cleanLabId)
        .where('cas', isEqualTo: cleanCas)
        .limit(50)
        .get();

    final labels = <String>[];
    for (final doc in snapshot.docs) {
      if (cleanExcludeId.isNotEmpty && doc.id == cleanExcludeId) {
        continue;
      }

      final data = doc.data() as Map<String, dynamic>;
      final label = (data['label'] ?? '').toString().trim();
      if (label.isNotEmpty) {
        labels.add(label);
      }
    }

    if (labels.isEmpty) return null;

    labels.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return labels.first;
  }

  Future<String?> getCasForLabel({
    required String labId,
    required String label,
    String? excludeDocId,
    String? differentFromCas,
  }) async {
    final cleanLabId = labId.trim();
    final cleanLabel = label.trim();
    final normalizedLabel = _normalizedLabel(cleanLabel);
    final cleanExcludeId = excludeDocId?.trim() ?? '';
    final cleanDifferentFromCas = differentFromCas?.trim() ?? '';

    if (cleanLabId.isEmpty || cleanLabel.isEmpty) {
      return null;
    }

    final snapshot = await inventoryRef
        .where('labId', isEqualTo: cleanLabId)
        .limit(1000)
        .get();

    for (final doc in snapshot.docs) {
      if (cleanExcludeId.isNotEmpty && doc.id == cleanExcludeId) {
        continue;
      }

      final data = doc.data() as Map<String, dynamic>;
      final existingLabel = (data['label'] ?? '').toString();
      if (_normalizedLabel(existingLabel) != normalizedLabel) {
        continue;
      }

      final existingCas = (data['cas'] ?? '').toString().trim();
      if (existingCas.isNotEmpty) {
        if (cleanDifferentFromCas.isNotEmpty &&
            existingCas == cleanDifferentFromCas) {
          continue;
        }
        return existingCas;
      }
    }

    return null;
  }

  Future<String?> validateCasLabelConsistency({
    required String labId,
    required String cas,
    required String label,
    String? excludeDocId,
    bool allowExistingLabelForSameCas = false,
  }) async {
    final cleanCas = cas.trim();
    final cleanLabel = label.trim();

    if (cleanCas.isEmpty || cleanLabel.isEmpty) {
      return null;
    }

    final existingLabel = await getExistingLabelForCas(
      labId: labId,
      cas: cleanCas,
      excludeDocId: excludeDocId,
    );

    if (!allowExistingLabelForSameCas &&
        existingLabel != null &&
        _normalizedLabel(existingLabel) != _normalizedLabel(cleanLabel)) {
      return 'This CAS already uses label $existingLabel. Please use the existing label to keep inventory consistent.';
    }

    final existingCas = await getCasForLabel(
      labId: labId,
      label: cleanLabel,
      excludeDocId: excludeDocId,
      differentFromCas: cleanCas,
    );

    if (existingCas != null && existingCas.trim() != cleanCas) {
      return 'Label $cleanLabel is already assigned to CAS $existingCas.';
    }

    return null;
  }

  Future<int> updateLabelForCas({
    required String labId,
    required String cas,
    required String label,
  }) async {
    final cleanLabId = labId.trim();
    final cleanCas = cas.trim();
    final cleanLabel = label.trim();

    if (cleanLabId.isEmpty) {
      throw Exception('Lab id is missing.');
    }
    if (cleanCas.isEmpty) {
      throw Exception('Chemical CAS is missing.');
    }
    if (cleanLabel.isEmpty) {
      throw Exception('Chemical label is required.');
    }

    final snapshot = await inventoryRef
        .where('labId', isEqualTo: cleanLabId)
        .where('cas', isEqualTo: cleanCas)
        .limit(500)
        .get();

    if (snapshot.docs.isEmpty) {
      return 0;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'label': cleanLabel,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return snapshot.docs.length;
  }

  Future<void> updateChemical(ChemicalModel chemical) async {
    final cleanDocId = chemical.id.trim();
    if (cleanDocId.isEmpty) {
      throw Exception('Chemical id is missing.');
    }

    await inventoryRef.doc(cleanDocId).update({
      ...chemical.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBottleDetails({
    required String bottleId,
    required String brand,
    required String quantity,
    required String location,
    required String texture,
    required String catNumber,
    required String orderedBy,
  }) async {
    final cleanBottleId = bottleId.trim();
    if (cleanBottleId.isEmpty) {
      throw Exception('Bottle id is missing.');
    }

    await inventoryRef.doc(cleanBottleId).update({
      'brand': brand.trim(),
      'quantity': quantity.trim(),
      'location': location.trim(),
      'texture': texture.trim(),
      'catNumber': catNumber.trim(),
      'orderedBy': orderedBy.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setActiveBottle({
    required String labId,
    required String cas,
    required String bottleId,
  }) async {
    final cleanLabId = labId.trim();
    final cleanCas = cas.trim();
    final cleanBottleId = bottleId.trim();

    if (cleanLabId.isEmpty) {
      throw Exception('Lab id is missing.');
    }
    if (cleanCas.isEmpty) {
      throw Exception('Chemical CAS is missing.');
    }
    if (cleanBottleId.isEmpty) {
      throw Exception('Bottle id is missing.');
    }

    final snapshot = await inventoryRef
        .where('labId', isEqualTo: cleanLabId)
        .where('cas', isEqualTo: cleanCas)
        .limit(500)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isActiveBottle': doc.id == cleanBottleId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
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

  Future<void> updateLocationsByIds({
    required Iterable<String> docIds,
    required String location,
  }) async {
    final cleanLocation = location.trim();
    final cleanDocIds = docIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanDocIds.isEmpty) {
      throw Exception('No inventory items selected.');
    }

    if (cleanLocation.isEmpty) {
      throw Exception('Location is required.');
    }

    const batchLimit = 450;
    for (var start = 0; start < cleanDocIds.length; start += batchLimit) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = cleanDocIds.skip(start).take(batchLimit);

      for (final docId in chunk) {
        batch.update(inventoryRef.doc(docId), {
          'location': cleanLocation,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  Future<void> updateAvailabilityByIds({
    required Iterable<String> docIds,
    required String availability,
  }) async {
    final cleanAvailability = availability.trim().toLowerCase();
    final cleanDocIds = docIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (cleanDocIds.isEmpty) {
      throw Exception('No inventory items selected.');
    }

    if (cleanAvailability.isEmpty) {
      throw Exception('Availability is required.');
    }

    const batchLimit = 450;
    for (var start = 0; start < cleanDocIds.length; start += batchLimit) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = cleanDocIds.skip(start).take(batchLimit);

      for (final docId in chunk) {
        batch.update(inventoryRef.doc(docId), {
          'availability': cleanAvailability,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
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

  Future<void> markBottleFinishedById({required String docId}) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) {
      throw Exception('Bottle id is missing.');
    }

    await inventoryRef.doc(cleanDocId).update({
      'availability': 'finished',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markBottleLowById({required String docId}) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) {
      throw Exception('Bottle id is missing.');
    }

    await inventoryRef.doc(cleanDocId).update({
      'availability': 'low',
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
        .where((doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>))
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
        .where((doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>))
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

    final snapshot = await inventoryRef.where('cas', isEqualTo: cleanCas).get();

    final bottles = snapshot.docs
        .where((doc) => _matchesCurrentLab(doc.data() as Map<String, dynamic>))
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

      final match = RegExp(
        '^${RegExp.escape(cleanPrefix)}-(\\d+)\$',
      ).firstMatch(label);

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
