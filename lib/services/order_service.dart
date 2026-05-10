import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import 'firestore_access_guard.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersSnapshots() {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    if (appState.isDemoLabSelected) {
      return _firestore.collection('orders').snapshots();
    }

    return _firestore
        .collection('orders')
        .where('labId', isEqualTo: selectedLabId)
        .snapshots();
  }

  Future<String> addOrder(OrderModel order) async {
    final doc = await _firestore.collection('orders').add(order.toMap());
    return doc.id;
  }

  Stream<List<OrderModel>> getOrders() {
    return FirestoreAccessGuard.guardLabStream<List<OrderModel>>(
      source: _ordersSnapshots(),
      emptyValue: <OrderModel>[],
      onData: (snapshot) {
        final docs = AppState.instance.isDemoLabSelected
            ? snapshot.docs.where((doc) => _matchesCurrentLab(doc.data()))
            : snapshot.docs;

        final orders = docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
        orders.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
        return orders;
      },
    );
  }

  Future<void> updateOrderStatus({
    required String docId,
    required String status,
    required String receivedBy,
  }) async {
    await _firestore.collection('orders').doc(docId).update({
      'status': status,
      'receivedBy': receivedBy,
      'deliveredAt': Timestamp.now(),
    });
  }

  Future<void> markInventoryAdded({required String docId}) async {
    await _firestore.collection('orders').doc(docId).update({
      'inventoryAdded': true,
    });
  }
}
