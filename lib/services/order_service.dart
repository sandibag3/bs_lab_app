import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Future<String> addOrder(OrderModel order) async {
    final doc = await _firestore.collection('orders').add(order.toMap());
    return doc.id;
  }

  Stream<List<OrderModel>> getOrders() {
    return _firestore
        .collection('orders')
        .orderBy('orderedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) => _matchesCurrentLab(doc.data()))
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
        });
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
