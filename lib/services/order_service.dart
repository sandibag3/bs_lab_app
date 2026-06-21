import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';
import 'firestore_access_guard.dart';

class OrderFinancialBackfillResult {
  const OrderFinancialBackfillResult({
    required this.scanned,
    required this.updated,
    required this.skipped,
    required this.unresolved,
  });

  final int scanned;
  final int updated;
  final int skipped;
  final int unresolved;
}

class OrderPlacementException implements Exception {
  const OrderPlacementException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderDeliveryException implements Exception {
  const OrderDeliveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderInventoryException implements Exception {
  const OrderInventoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderService {
  static const int _backfillBatchChunkSize = 400;

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

  DocumentReference<Map<String, dynamic>> _requirementRef(
    String requirementId,
  ) {
    return _firestore.collection('requirements').doc(requirementId);
  }

  Future<String> addOrder(OrderModel order) async {
    final doc = await _firestore.collection('orders').add(order.toMap());
    return doc.id;
  }

  Future<String> placeOrderAndMarkRequirementOrdered({
    required OrderModel order,
    required String updatedBy,
  }) async {
    final orderRef = _firestore.collection('orders').doc();
    final requirementRef = _requirementRef(order.requirementId);
    final orderWithId = order.copyWith(id: orderRef.id);

    await _firestore.runTransaction((transaction) async {
      final requirementSnapshot = await transaction.get(requirementRef);
      final requirementData = requirementSnapshot.data();

      if (!requirementSnapshot.exists || requirementData == null) {
        throw const OrderPlacementException('Requirement no longer exists.');
      }

      final existingOrderId = (requirementData['orderId'] ?? '')
          .toString()
          .trim();
      if (existingOrderId.isNotEmpty) {
        throw const OrderPlacementException(
          'This requirement has already been ordered.',
        );
      }

      final status = (requirementData['status'] ?? '').toString();
      if (status.trim().toLowerCase() != 'approved') {
        throw const OrderPlacementException(
          'This requirement can no longer be ordered because its status has changed.',
        );
      }

      final requirementLabId = (requirementData['labId'] ?? '')
          .toString()
          .trim();
      final orderLabId = orderWithId.labId.trim();
      if (requirementLabId.isNotEmpty &&
          orderLabId.isNotEmpty &&
          requirementLabId != orderLabId) {
        throw const OrderPlacementException(
          'This requirement does not belong to the active lab.',
        );
      }

      final serverTimestamp = FieldValue.serverTimestamp();
      final requirementUpdates = <String, dynamic>{
        'status': 'ordered',
        'orderId': orderRef.id,
        'orderedAt': serverTimestamp,
      };
      final cleanUpdatedBy = updatedBy.trim();
      if (cleanUpdatedBy.isNotEmpty) {
        requirementUpdates['orderedBy'] = cleanUpdatedBy;
      }

      transaction.set(orderRef, orderWithId.toMap());
      transaction.update(requirementRef, requirementUpdates);
    });

    return orderRef.id;
  }

  Stream<List<OrderModel>> getOrders() {
    return FirestoreAccessGuard.guardLabStream<List<OrderModel>>(
      source: _ordersSnapshots(),
      emptyValue: <OrderModel>[],
      onData: (snapshot) {
        final docs = AppState.instance.isDemoLabSelected
            ? snapshot.docs.where((doc) => _matchesCurrentLab(doc.data()))
            : snapshot.docs;

        final orders = docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList();
        orders.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
        return orders;
      },
    );
  }

  Future<OrderFinancialBackfillResult> backfillOrderFinancialSnapshots({
    required String labId,
  }) async {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      throw ArgumentError('Lab ID is required.');
    }

    final snapshot = await _firestore
        .collection('orders')
        .where('labId', isEqualTo: cleanLabId)
        .get();

    var scanned = 0;
    var updated = 0;
    var skipped = 0;
    var unresolved = 0;

    final requirementCache =
        <String, DocumentSnapshot<Map<String, dynamic>>?>{};
    final pendingUpdates =
        <
          MapEntry<
            DocumentReference<Map<String, dynamic>>,
            Map<String, dynamic>
          >
        >[];

    for (final doc in snapshot.docs) {
      scanned++;
      final order = OrderModel.fromFirestore(doc);
      final cleanRequirementId = order.requirementId.trim();
      final cleanFundAdjustmentTransactionId =
          order.fundAdjustmentTransactionId?.trim() ?? '';

      if (order.costReconciled || cleanFundAdjustmentTransactionId.isNotEmpty) {
        skipped++;
        continue;
      }

      if (cleanRequirementId.isEmpty) {
        skipped++;
        continue;
      }

      final needsEstimatedTotal = order.estimatedTotal == null;
      final needsFundId = (order.fundId?.trim() ?? '').isEmpty;
      final needsFundNameSnapshot =
          (order.fundNameSnapshot?.trim() ?? '').isEmpty;
      final needsFundCodeSnapshot =
          (order.fundCodeSnapshot?.trim() ?? '').isEmpty;
      final allocatedAmount = order.allocatedAmount;
      final needsAllocatedAmount =
          allocatedAmount == null ||
          !allocatedAmount.isFinite ||
          allocatedAmount <= 0;
      final needsFundTransactionId =
          (order.fundTransactionId?.trim() ?? '').isEmpty;

      final needsRepair =
          needsEstimatedTotal ||
          needsFundId ||
          needsFundNameSnapshot ||
          needsAllocatedAmount ||
          needsFundTransactionId;

      if (!needsRepair) {
        skipped++;
        continue;
      }

      final requirementSnapshot =
          requirementCache[cleanRequirementId] ??
          await _requirementRef(cleanRequirementId).get();
      requirementCache[cleanRequirementId] = requirementSnapshot;

      if (!requirementSnapshot.exists || requirementSnapshot.data() == null) {
        unresolved++;
        continue;
      }

      final requirement = RequirementModel.fromFirestore(requirementSnapshot);
      if (requirement.labId.trim() != cleanLabId) {
        unresolved++;
        continue;
      }

      final updateData = <String, dynamic>{};
      final parsedEstimatedTotal = needsEstimatedTotal
          ? _parseRequirementEstimatedTotal(requirement.estimatedTotal)
          : null;
      if (needsEstimatedTotal && parsedEstimatedTotal != null) {
        updateData['estimatedTotal'] = parsedEstimatedTotal;
      }

      final requirementFundId = requirement.fundId?.trim() ?? '';
      final requirementFundName = _normalizedOptionalString(
        requirement.fundNameSnapshot,
      );
      final requirementFundCode = _normalizedOptionalString(
        requirement.fundCodeSnapshot,
      );
      final requirementAllocatedAmount = requirement.allocatedAmount;
      final requirementFundTransactionId =
          requirement.fundTransactionId?.trim() ?? '';
      final hasValidRequirementAllocation =
          requirementFundId.isNotEmpty &&
          requirementAllocatedAmount != null &&
          requirementAllocatedAmount.isFinite &&
          requirementAllocatedAmount > 0 &&
          requirementFundTransactionId.isNotEmpty;

      if (hasValidRequirementAllocation) {
        if (needsFundId) {
          updateData['fundId'] = requirementFundId;
        }
        if (needsFundNameSnapshot && requirementFundName != null) {
          updateData['fundNameSnapshot'] = requirementFundName;
        }
        if (needsFundCodeSnapshot && requirementFundCode != null) {
          updateData['fundCodeSnapshot'] = requirementFundCode;
        }
        if (needsAllocatedAmount) {
          updateData['allocatedAmount'] = _roundCurrency(
            requirementAllocatedAmount,
          );
        }
        if (needsFundTransactionId) {
          updateData['fundTransactionId'] = requirementFundTransactionId;
        }
      }

      if (updateData.isEmpty) {
        unresolved++;
        continue;
      }

      pendingUpdates.add(MapEntry(doc.reference, updateData));
      updated++;
    }

    for (
      var start = 0;
      start < pendingUpdates.length;
      start += _backfillBatchChunkSize
    ) {
      final batch = _firestore.batch();
      final end = (start + _backfillBatchChunkSize) > pendingUpdates.length
          ? pendingUpdates.length
          : (start + _backfillBatchChunkSize);

      for (var index = start; index < end; index++) {
        final update = pendingUpdates[index];
        batch.update(update.key, update.value);
      }

      await batch.commit();
    }

    return OrderFinancialBackfillResult(
      scanned: scanned,
      updated: updated,
      skipped: skipped,
      unresolved: unresolved,
    );
  }

  Future<void> updateOrderStatus({
    required String docId,
    required String status,
    required String receivedBy,
  }) async {
    if (status.trim().toLowerCase() == 'delivered') {
      await _markOrderDeliveredTransactionally(
        docId: docId,
        receivedBy: receivedBy,
      );
      return;
    }

    await _firestore.collection('orders').doc(docId).update({
      'status': status,
      'receivedBy': receivedBy,
      'deliveredAt': Timestamp.now(),
    });
  }

  Future<void> _markOrderDeliveredTransactionally({
    required String docId,
    required String receivedBy,
  }) async {
    final orderRef = _firestore.collection('orders').doc(docId);

    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      final orderData = orderSnapshot.data();

      if (!orderSnapshot.exists || orderData == null) {
        throw const OrderDeliveryException('Order no longer exists.');
      }

      final currentStatus = (orderData['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (currentStatus == 'delivered') {
        throw const OrderDeliveryException(
          'This order has already been delivered.',
        );
      }

      if (currentStatus != 'ordered') {
        throw const OrderDeliveryException(
          'This order can no longer be marked as delivered because its status has changed.',
        );
      }

      transaction.update(orderRef, {
        'status': 'delivered',
        'receivedBy': receivedBy,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markInventoryAdded({
    required String docId,
    String? inventoryRecordId,
    String? inventoryAddedBy,
  }) async {
    final updates = <String, dynamic>{
      'inventoryAdded': true,
      'inventoryAddedAt': FieldValue.serverTimestamp(),
      'inventoryRecordId': inventoryRecordId,
      'inventoryAddedBy': inventoryAddedBy,
    };

    await _firestore.collection('orders').doc(docId).update(updates);
  }

  String? _normalizedOptionalString(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  double? _parseRequirementEstimatedTotal(String rawValue) {
    var cleaned = rawValue.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    cleaned = cleaned.replaceAll(',', '').trim();
    cleaned = cleaned
        .replaceFirst(
          RegExp('^(?:\\u20B9|â‚¹|Ã¢â€šÂ¹|ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¹)\\s*'),
          '',
        )
        .trim();

    final parsed = double.tryParse(cleaned);
    if (parsed == null || !parsed.isFinite) {
      return null;
    }

    return _roundCurrency(parsed);
  }

  double _roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
