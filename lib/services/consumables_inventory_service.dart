import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';
import 'firestore_access_guard.dart';

class ConsumablesInventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _inventorySnapshots() {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    if (appState.isDemoLabSelected) {
      return _firestore.collection('consumables_inventory').snapshots();
    }

    return _firestore
        .collection('consumables_inventory')
        .where('labId', isEqualTo: selectedLabId)
        .snapshots();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getConsumablesInventoryDocs() {
    return FirestoreAccessGuard.guardLabStream<
      List<QueryDocumentSnapshot<Map<String, dynamic>>>
    >(
      source: _inventorySnapshots(),
      emptyValue: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      onData: (snapshot) {
        if (AppState.instance.isDemoLabSelected) {
          return snapshot.docs.where((doc) {
            final labId = (doc.data()['labId'] ?? '').toString().trim();
            return AppState.instance.matchesSelectedLabId(labId);
          }).toList();
        }

        return snapshot.docs.toList();
      },
    );
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
      throw Exception('No consumable items selected.');
    }

    if (cleanLocation.isEmpty) {
      throw Exception('Location is required.');
    }

    const batchLimit = 450;
    for (var start = 0; start < cleanDocIds.length; start += batchLimit) {
      final batch = _firestore.batch();
      final chunk = cleanDocIds.skip(start).take(batchLimit);

      for (final docId in chunk) {
        batch.update(_firestore.collection('consumables_inventory').doc(docId), {
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
      throw Exception('No consumable items selected.');
    }

    if (cleanAvailability.isEmpty) {
      throw Exception('Availability is required.');
    }

    const batchLimit = 450;
    for (var start = 0; start < cleanDocIds.length; start += batchLimit) {
      final batch = _firestore.batch();
      final chunk = cleanDocIds.skip(start).take(batchLimit);

      for (final docId in chunk) {
        batch.update(_firestore.collection('consumables_inventory').doc(docId), {
          'availability': cleanAvailability,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }
}
