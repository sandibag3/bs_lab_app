import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addOrder(OrderModel order) async {
    await _firestore.collection('orders').add(order.toMap());
  }

  Stream<List<OrderModel>> getOrders() {
    return _firestore
        .collection('orders')
        .orderBy('orderedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
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

  Future<void> markInventoryAdded({
    required String docId,
  }) async {
    await _firestore.collection('orders').doc(docId).update({
      'inventoryAdded': true,
    });
  }
}