import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';
import '../models/order_model.dart';
import 'firestore_access_guard.dart';
import 'order_service.dart';

class ConsumableInventoryConfirmationResult {
  const ConsumableInventoryConfirmationResult({required this.inventoryId});

  final String inventoryId;
}

class ConsumablesInventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _inventoryKey(String consumableType) {
    return consumableType.trim().toLowerCase();
  }

  double? _readQuantityNumber(String quantity) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0) ?? '');
  }

  String _formatQuantityNumber(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }

    return quantity.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }

  void _validateOrderForInventory(
    DocumentSnapshot<Map<String, dynamic>> orderSnapshot,
  ) {
    final orderData = orderSnapshot.data();

    if (!orderSnapshot.exists || orderData == null) {
      throw const OrderInventoryException('Order no longer exists.');
    }

    final status = (orderData['status'] ?? '').toString().trim().toLowerCase();
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
  }

  Future<ConsumableInventoryConfirmationResult> confirmDeliveredOrder({
    required OrderModel order,
    required String labId,
    required String consumableType,
    required double quantityAdded,
    required String brand,
    required String vendor,
    required String location,
    required String modeOfPurchase,
    required String orderedBy,
    String? inventoryAddedBy,
  }) async {
    final cleanOrderId = order.id.trim();
    final cleanLabId = labId.trim();
    final cleanConsumableType = consumableType.trim();
    final cleanBrand = brand.trim();
    final cleanVendor = vendor.trim();
    final cleanLocation = location.trim();
    final cleanModeOfPurchase = modeOfPurchase.trim();
    final cleanOrderedBy = orderedBy.trim();
    final cleanInventoryAddedBy = inventoryAddedBy?.trim() ?? '';

    if (cleanOrderId.isEmpty) {
      throw Exception('Order id is missing.');
    }
    if (cleanConsumableType.isEmpty) {
      throw Exception('Consumable type is required.');
    }
    if (quantityAdded <= 0) {
      throw Exception('Quantity must be numeric and greater than 0.');
    }

    final inventoryRef = _firestore.collection('consumables_inventory');
    final purchaseLogRef = _firestore
        .collection('consumable_purchase_logs')
        .doc();
    final orderRef = _firestore.collection('orders').doc(cleanOrderId);

    final existingSnapshot = await inventoryRef.get();
    final targetKey = _inventoryKey(cleanConsumableType);
    QueryDocumentSnapshot<Map<String, dynamic>>? existingDoc;

    for (final doc in existingSnapshot.docs) {
      final data = doc.data();
      final docLabId = (data['labId'] ?? '').toString().trim();
      if (docLabId != cleanLabId) {
        continue;
      }

      final docKey = _inventoryKey((data['consumableType'] ?? '').toString());
      if (docKey == targetKey) {
        existingDoc = doc;
        break;
      }
    }

    late final String inventoryId;

    if (existingDoc == null) {
      final newInventoryRef = inventoryRef.doc();
      inventoryId = newInventoryRef.id;

      await _firestore.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        _validateOrderForInventory(orderSnapshot);

        const previousQuantity = 0.0;
        final newQuantity = quantityAdded;
        final timestamp = Timestamp.now();
        final serverTimestamp = FieldValue.serverTimestamp();
        final deliveredAt = order.deliveredAt ?? timestamp;
        final orderUpdates = <String, dynamic>{
          'inventoryAdded': true,
          'inventoryAddedAt': serverTimestamp,
          'inventoryRecordId': inventoryId,
        };
        if (cleanInventoryAddedBy.isNotEmpty) {
          orderUpdates['inventoryAddedBy'] = cleanInventoryAddedBy;
        }

        transaction.set(newInventoryRef, {
          'labId': cleanLabId,
          'mainType': 'consumable',
          'orderId': cleanOrderId,
          'latestOrderId': cleanOrderId,
          'requirementId': order.requirementId,
          'consumableType': cleanConsumableType,
          'quantity': _formatQuantityNumber(newQuantity),
          'isAggregate': true,
          'brand': cleanBrand,
          'latestBrand': cleanBrand,
          'vendor': cleanVendor,
          'latestVendor': cleanVendor,
          'location': cleanLocation,
          'modeOfPurchase': cleanModeOfPurchase,
          'orderedBy': cleanOrderedBy,
          'receivedBy': order.receivedBy,
          'deliveredAt': deliveredAt,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });

        transaction.set(purchaseLogRef, {
          'labId': cleanLabId,
          'consumableInventoryId': inventoryId,
          'consumableType': cleanConsumableType,
          'quantityAdded': quantityAdded,
          'previousQuantity': previousQuantity,
          'newQuantity': newQuantity,
          'brand': cleanBrand,
          'vendor': cleanVendor,
          'location': cleanLocation,
          'modeOfPurchase': cleanModeOfPurchase,
          'receivedBy': order.receivedBy,
          'deliveredAt': deliveredAt,
          'sourceOrderId': cleanOrderId,
          'createdAt': timestamp,
          'createdBy': AppState.instance.authenticatedUserId,
          'actorName': AppState.instance.authenticatedUserName,
        });

        transaction.update(orderRef, orderUpdates);
      });
    } else {
      final matchedDoc = existingDoc;
      inventoryId = matchedDoc.id;

      await _firestore.runTransaction((transaction) async {
        final orderSnapshot = await transaction.get(orderRef);
        final freshSnapshot = await transaction.get(matchedDoc.reference);
        _validateOrderForInventory(orderSnapshot);

        final freshData = freshSnapshot.data();
        if (freshData == null) {
          throw Exception('Existing consumable inventory item was removed.');
        }

        final currentQuantity = _readQuantityNumber(
          (freshData['quantity'] ?? '').toString(),
        );
        final previousQuantity = currentQuantity ?? 0;
        final newQuantity = previousQuantity + quantityAdded;
        final timestamp = Timestamp.now();
        final serverTimestamp = FieldValue.serverTimestamp();
        final deliveredAt = order.deliveredAt ?? timestamp;
        final orderUpdates = <String, dynamic>{
          'inventoryAdded': true,
          'inventoryAddedAt': serverTimestamp,
          'inventoryRecordId': inventoryId,
        };
        if (cleanInventoryAddedBy.isNotEmpty) {
          orderUpdates['inventoryAddedBy'] = cleanInventoryAddedBy;
        }

        transaction.update(matchedDoc.reference, {
          'quantity': _formatQuantityNumber(newQuantity),
          'isAggregate': true,
          'latestOrderId': cleanOrderId,
          'requirementId': order.requirementId,
          if (cleanBrand.isNotEmpty) 'brand': cleanBrand,
          'latestBrand': cleanBrand,
          if (cleanVendor.isNotEmpty) 'vendor': cleanVendor,
          'latestVendor': cleanVendor,
          if (cleanLocation.isNotEmpty) 'location': cleanLocation,
          'modeOfPurchase': cleanModeOfPurchase,
          'orderedBy': cleanOrderedBy,
          'receivedBy': order.receivedBy,
          'deliveredAt': deliveredAt,
          'updatedAt': timestamp,
        });

        transaction.set(purchaseLogRef, {
          'labId': cleanLabId,
          'consumableInventoryId': inventoryId,
          'consumableType': cleanConsumableType,
          'quantityAdded': quantityAdded,
          'previousQuantity': previousQuantity,
          'newQuantity': newQuantity,
          'brand': cleanBrand,
          'vendor': cleanVendor,
          'location': cleanLocation,
          'modeOfPurchase': cleanModeOfPurchase,
          'receivedBy': order.receivedBy,
          'deliveredAt': deliveredAt,
          'sourceOrderId': cleanOrderId,
          'createdAt': timestamp,
          'createdBy': AppState.instance.authenticatedUserId,
          'actorName': AppState.instance.authenticatedUserName,
        });

        transaction.update(orderRef, orderUpdates);
      });
    }

    return ConsumableInventoryConfirmationResult(inventoryId: inventoryId);
  }

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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getConsumablesInventoryDocsOnce() async {
    if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }

    try {
      final appState = AppState.instance;
      final selectedLabId = appState.selectedLabId.trim();
      final snapshot = appState.isDemoLabSelected
          ? await _firestore.collection('consumables_inventory').get()
          : await _firestore
                .collection('consumables_inventory')
                .where('labId', isEqualTo: selectedLabId)
                .get();

      if (appState.isDemoLabSelected) {
        return snapshot.docs.where((doc) {
          final labId = (doc.data()['labId'] ?? '').toString().trim();
          return AppState.instance.matchesSelectedLabId(labId);
        }).toList();
      }

      return snapshot.docs.toList();
    } on FirebaseException catch (error) {
      if (FirestoreAccessGuard.isPermissionDenied(error)) {
        throw const LabDataAccessException();
      }
      rethrow;
    }
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
        batch.update(
          _firestore.collection('consumables_inventory').doc(docId),
          {
            'location': cleanLocation,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
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
        batch
            .update(_firestore.collection('consumables_inventory').doc(docId), {
              'availability': cleanAvailability,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      await batch.commit();
    }
  }
}
