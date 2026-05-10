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
}
