import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fund_model.dart';
import '../models/fund_transaction_model.dart';
import '../models/order_model.dart';
import '../models/purchase_order_model.dart';
import 'firestore_access_guard.dart';

class PurchaseOrderService {
  static const int _maxOrdersPerPurchaseOrder = 50;
  static const double _amountTolerance = 0.000001;
  static const double _allocationComparisonTolerance = 0.01;
  static const String _draftStatus = 'draft';
  static const String _submittedStatus = 'submitted';
  static const String _processingStatus = 'processing';
  static const String _completedStatus = 'completed';
  static const String _cancelledStatus = 'cancelled';
  static const String _adjustmentTransactionType = 'adjustment';
  static const String _refundTransactionType = 'refund';
  static const String _reconciliationTransactionType = 'reconciliation';
  static const String _fallbackFundName = 'Fund';

  PurchaseOrderService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  CollectionReference<Map<String, dynamic>> _fundsRef(String labId) {
    return _firestore.collection('labs').doc(labId).collection('funds');
  }

  CollectionReference<Map<String, dynamic>> _fundTransactionsRef(
    String labId,
    String fundId,
  ) {
    return _fundsRef(labId).doc(fundId).collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> _purchaseOrdersRef(String labId) {
    return _firestore
        .collection('labs')
        .doc(labId)
        .collection('purchaseOrders');
  }

  Future<String> createPurchaseOrder({
    required String labId,
    required List<String> orderIds,
    required String createdBy,
    String? title,
    String? indentNumber,
    String? institutePoNumber,
    String? vendor,
    String? modeOfPurchase,
    String? notes,
  }) async {
    return _runGuarded(() async {
      final cleanLabId = _validatedLabId(labId);
      final cleanCreatedBy = _validatedCreatedBy(createdBy);
      final cleanOrderIds = _validatedOrderIds(orderIds);
      final cleanTitle = _normalizedOptionalString(title);
      final cleanIndentNumber = _normalizedOptionalString(indentNumber);
      final cleanInstitutePoNumber = _normalizedOptionalString(
        institutePoNumber,
      );
      final cleanVendor = _normalizedOptionalString(vendor);
      final cleanModeOfPurchase = _normalizedOptionalString(modeOfPurchase);
      final cleanNotes = _normalizedOptionalString(notes);

      final purchaseOrderRef = _purchaseOrdersRef(cleanLabId).doc();
      final purchaseOrderId = purchaseOrderRef.id;
      final folderNumber = _buildFolderNumber(purchaseOrderId);
      final orderRefs = cleanOrderIds
          .map((orderId) => _ordersRef.doc(orderId))
          .toList(growable: false);

      await _firestore.runTransaction((transaction) async {
        final orderSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final orderRef in orderRefs) {
          orderSnapshots.add(await transaction.get(orderRef));
        }

        if (orderSnapshots.any((snapshot) => !snapshot.exists)) {
          throw StateError('One or more selected orders could not be found.');
        }

        final validatedOrders = <_ValidatedPurchaseOrderSource>[];
        String? requiredFundId;
        String? fundNameSnapshot;
        String? fundCodeSnapshot;
        double allocatedTotal = 0.0;
        double estimatedTotal = 0.0;

        for (final orderSnapshot in orderSnapshots) {
          final order = OrderModel.fromFirestore(orderSnapshot);

          if (order.labId.trim() != cleanLabId) {
            throw StateError(
              'All selected orders must belong to the active lab.',
            );
          }

          final normalizedStatus = _normalizedStatus(order.status);
          if (normalizedStatus != 'ordered' &&
              normalizedStatus != 'delivered') {
            throw StateError(
              'Only ordered or delivered orders can be added to a Purchase Order.',
            );
          }

          final cleanFundId = order.fundId?.trim() ?? '';
          final cleanFundTransactionId = order.fundTransactionId?.trim() ?? '';
          final allocatedAmount = order.allocatedAmount;

          if (cleanFundId.isEmpty || cleanFundTransactionId.isEmpty) {
            throw StateError(
              'Every selected order must have a valid fund allocation.',
            );
          }

          if (allocatedAmount == null ||
              !allocatedAmount.isFinite ||
              allocatedAmount <= 0) {
            throw StateError(
              'Every selected order must have a valid fund allocation.',
            );
          }

          final normalizedAllocatedAmount = _normalizeCurrency(allocatedAmount);
          if (normalizedAllocatedAmount <= 0) {
            throw StateError(
              'Every selected order must have a valid fund allocation.',
            );
          }

          if ((order.purchaseOrderId?.trim() ?? '').isNotEmpty) {
            throw StateError(
              'One or more selected orders already belong to a Purchase Order.',
            );
          }

          if (order.costReconciled ||
              (order.fundAdjustmentTransactionId?.trim() ?? '').isNotEmpty) {
            throw StateError(
              'Individually reconciled orders cannot be added to a Purchase Order.',
            );
          }

          if (requiredFundId == null) {
            requiredFundId = cleanFundId;
          } else if (requiredFundId != cleanFundId) {
            throw StateError(
              'Selected orders use different funds and cannot be grouped into one Purchase Order.',
            );
          }

          fundNameSnapshot ??= _normalizedOptionalString(
            order.fundNameSnapshot,
          );
          fundCodeSnapshot ??= _normalizedOptionalString(
            order.fundCodeSnapshot,
          );

          allocatedTotal = _normalizeCurrency(
            allocatedTotal + normalizedAllocatedAmount,
          );

          final orderEstimatedTotal = order.estimatedTotal;
          if (orderEstimatedTotal != null &&
              orderEstimatedTotal.isFinite &&
              orderEstimatedTotal > 0) {
            estimatedTotal = _normalizeCurrency(
              estimatedTotal + _normalizeCurrency(orderEstimatedTotal),
            );
          }

          validatedOrders.add(
            _ValidatedPurchaseOrderSource(
              reference: orderSnapshot.reference,
              order: order,
            ),
          );
        }

        if (validatedOrders.isEmpty || requiredFundId == null) {
          throw StateError('One or more selected orders could not be found.');
        }

        final resolvedVendor =
            cleanVendor ??
            _deriveSharedNonEmptyValue(
              validatedOrders.map((entry) => entry.order.vendor),
            );
        final resolvedModeOfPurchase =
            cleanModeOfPurchase ??
            _deriveSharedNonEmptyValue(
              validatedOrders.map((entry) => entry.order.modeOfPurchase),
            );
        final serverTimestamp = FieldValue.serverTimestamp();

        transaction.set(purchaseOrderRef, {
          'labId': cleanLabId,
          'folderNumber': folderNumber,
          'institutePoNumber': cleanInstitutePoNumber,
          'indentNumber': cleanIndentNumber,
          'title': cleanTitle,
          'fundId': requiredFundId,
          'fundNameSnapshot': fundNameSnapshot ?? _fallbackFundName,
          'fundCodeSnapshot': fundCodeSnapshot,
          'orderIds': cleanOrderIds,
          'orderCount': validatedOrders.length,
          'estimatedTotal': _normalizeCurrency(estimatedTotal),
          'allocatedTotal': _normalizeCurrency(allocatedTotal),
          'actualTotal': null,
          'reconciledDeltaAmount': null,
          'status': _draftStatus,
          'createdBy': cleanCreatedBy,
          'createdAt': serverTimestamp,
          'updatedAt': serverTimestamp,
          'actualCostRecordedBy': null,
          'actualCostRecordedAt': null,
          'costReconciled': false,
          'costReconciledBy': null,
          'costReconciledAt': null,
          'fundTransactionId': null,
          'vendor': resolvedVendor,
          'modeOfPurchase': resolvedModeOfPurchase,
          'notes': cleanNotes,
        });

        for (final validatedOrder in validatedOrders) {
          transaction.update(validatedOrder.reference, {
            'purchaseOrderId': purchaseOrderId,
            'purchaseOrderNumber': folderNumber,
            'purchaseOrderStatus': _draftStatus,
            'purchaseOrderAssignedAt': serverTimestamp,
            'purchaseOrderAssignedBy': cleanCreatedBy,
          });
        }
      });

      return purchaseOrderId;
    });
  }

  Stream<List<PurchaseOrderModel>> streamPurchaseOrders(String labId) {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return Stream<List<PurchaseOrderModel>>.value(
        const <PurchaseOrderModel>[],
      );
    }

    return _purchaseOrdersRef(cleanLabId).snapshots().transform(
      StreamTransformer<
        QuerySnapshot<Map<String, dynamic>>,
        List<PurchaseOrderModel>
      >.fromHandlers(
        handleData: (snapshot, sink) {
          final purchaseOrders = snapshot.docs
              .map(PurchaseOrderModel.fromFirestore)
              .toList();
          purchaseOrders.sort(_comparePurchaseOrders);
          sink.add(purchaseOrders);
        },
        handleError: (error, stackTrace, sink) {
          if (FirestoreAccessGuard.isPermissionDenied(error)) {
            sink.addError(const LabDataAccessException(), stackTrace);
            return;
          }

          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  Future<List<OrderModel>> getPurchaseOrderOrders({
    required String labId,
    required List<String> orderIds,
  }) async {
    return _runGuarded(() async {
      final cleanLabId = _validatedLabId(labId);
      if (orderIds.isEmpty) {
        return const <OrderModel>[];
      }

      final resolvedOrders = <OrderModel>[];
      for (final rawOrderId in orderIds) {
        final cleanOrderId = rawOrderId.trim();
        if (cleanOrderId.isEmpty) {
          continue;
        }

        final snapshot = await _ordersRef.doc(cleanOrderId).get();
        if (!snapshot.exists || snapshot.data() == null) {
          continue;
        }

        final order = OrderModel.fromFirestore(snapshot);
        if (order.labId.trim() != cleanLabId) {
          continue;
        }

        resolvedOrders.add(order);
      }

      return resolvedOrders;
    });
  }

  Future<void> reconcilePurchaseOrderActualCost({
    required String purchaseOrderId,
    required String labId,
    required double actualTotal,
    required String reconciledBy,
  }) async {
    return _runGuarded(() async {
      final cleanPurchaseOrderId = _validatedPurchaseOrderId(purchaseOrderId);
      final cleanLabId = _validatedLabId(labId);
      final normalizedActualTotal = _validatedActualTotal(actualTotal);
      final cleanReconciledBy = _validatedCreatedBy(reconciledBy);

      final purchaseOrderRef = _purchaseOrdersRef(
        cleanLabId,
      ).doc(cleanPurchaseOrderId);

      await _firestore.runTransaction((transaction) async {
        final purchaseOrderSnapshot = await transaction.get(purchaseOrderRef);
        if (!purchaseOrderSnapshot.exists ||
            purchaseOrderSnapshot.data() == null) {
          throw StateError('Purchase Order could not be found.');
        }

        final purchaseOrder = PurchaseOrderModel.fromFirestore(
          purchaseOrderSnapshot,
        );
        if (purchaseOrder.labId.trim() != cleanLabId) {
          throw StateError('Purchase Order does not belong to the active lab.');
        }

        final purchaseOrderStatus = _normalizedStatus(purchaseOrder.status);
        if (purchaseOrderStatus == _cancelledStatus) {
          throw StateError('Cancelled Purchase Orders cannot be reconciled.');
        }
        if (!_isAllowedReconciliationPurchaseOrderStatus(purchaseOrderStatus)) {
          throw StateError(
            'This Purchase Order is not in a valid state for reconciliation.',
          );
        }
        if (purchaseOrder.costReconciled ||
            (purchaseOrder.fundTransactionId?.trim().isNotEmpty ?? false)) {
          throw StateError('This Purchase Order has already been reconciled.');
        }

        final cleanFundId = purchaseOrder.fundId.trim();
        if (cleanFundId.isEmpty) {
          throw StateError('This Purchase Order has no linked fund.');
        }

        final cleanOrderIds = purchaseOrder.orderIds
            .map((orderId) => orderId.trim())
            .where((orderId) => orderId.isNotEmpty)
            .toList(growable: false);
        if (cleanOrderIds.isEmpty) {
          throw StateError('This Purchase Order has no linked orders.');
        }

        final normalizedAllocatedTotal = _normalizeCurrency(
          purchaseOrder.allocatedTotal,
        );
        if (!normalizedAllocatedTotal.isFinite ||
            normalizedAllocatedTotal <= 0) {
          throw StateError('This Purchase Order has no valid allocated total.');
        }

        final orderRefs = cleanOrderIds
            .map((orderId) => _ordersRef.doc(orderId))
            .toList(growable: false);
        final orderSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final orderRef in orderRefs) {
          orderSnapshots.add(await transaction.get(orderRef));
        }

        if (orderSnapshots.any((snapshot) => !snapshot.exists)) {
          throw StateError('One or more linked orders could not be found.');
        }

        double linkedAllocatedTotal = 0.0;
        for (final orderSnapshot in orderSnapshots) {
          final order = OrderModel.fromFirestore(orderSnapshot);

          if (order.labId.trim() != cleanLabId) {
            throw StateError(
              'One or more linked orders do not belong to the active lab.',
            );
          }

          if ((order.purchaseOrderId?.trim() ?? '') != cleanPurchaseOrderId) {
            throw StateError(
              'One or more linked orders are not assigned to this Purchase Order.',
            );
          }

          if ((order.fundId?.trim() ?? '') != cleanFundId) {
            throw StateError(
              'All Purchase Order orders must use the same fund.',
            );
          }

          if (order.costReconciled ||
              (order.fundAdjustmentTransactionId?.trim().isNotEmpty ?? false)) {
            throw StateError(
              'An individually reconciled order cannot be reconciled again through a Purchase Order.',
            );
          }

          final allocatedAmount = order.allocatedAmount;
          if (allocatedAmount == null ||
              !allocatedAmount.isFinite ||
              allocatedAmount <= 0) {
            throw StateError(
              'One or more linked orders have no valid allocated amount.',
            );
          }

          linkedAllocatedTotal = _normalizeCurrency(
            linkedAllocatedTotal + _normalizeCurrency(allocatedAmount),
          );
        }

        if ((linkedAllocatedTotal - normalizedAllocatedTotal).abs() >
            _allocationComparisonTolerance) {
          throw StateError(
            'The Purchase Order allocated total does not match its linked orders.',
          );
        }

        final fundRef = _fundsRef(cleanLabId).doc(cleanFundId);
        final fundSnapshot = await transaction.get(fundRef);
        if (!fundSnapshot.exists || fundSnapshot.data() == null) {
          throw StateError('Fund could not be found.');
        }

        final fund = FundModel.fromFirestore(fundSnapshot);
        if (fund.labId.trim() != cleanLabId) {
          throw StateError('Fund does not belong to the active lab.');
        }
        if (!fund.availableAmount.isFinite) {
          throw StateError(
            'This fund does not have a valid available balance.',
          );
        }
        if (fund.effectiveStatus == FundModel.statusClosed) {
          throw StateError('Closed funds cannot be reconciled.');
        }

        final ledgerDocumentId = _purchaseOrderLedgerDocumentId(
          cleanPurchaseOrderId,
        );
        final ledgerRef = _fundTransactionsRef(
          cleanLabId,
          cleanFundId,
        ).doc(ledgerDocumentId);
        final ledgerSnapshot = await transaction.get(ledgerRef);
        if (ledgerSnapshot.exists) {
          throw StateError('This Purchase Order has already been reconciled.');
        }

        final normalizedDelta = _normalizeCurrency(
          normalizedActualTotal - normalizedAllocatedTotal,
        );
        final currentAvailableAmount = _normalizeCurrency(fund.availableAmount);

        double? updatedAvailableAmount;
        if (normalizedDelta > 0) {
          if (currentAvailableAmount < normalizedDelta) {
            throw StateError(
              'This fund does not have sufficient available balance for the additional Purchase Order cost.',
            );
          }

          updatedAvailableAmount = _normalizeCurrency(
            currentAvailableAmount - normalizedDelta,
          );
        } else if (normalizedDelta < 0) {
          updatedAvailableAmount = _normalizeCurrency(
            currentAvailableAmount + normalizedDelta.abs(),
          );
        }

        final serverTimestamp = FieldValue.serverTimestamp();
        final purchaseOrderDisplayNumber = _resolvedPurchaseOrderDisplayNumber(
          purchaseOrder,
        );
        final fundNameSnapshot =
            _normalizedOptionalString(purchaseOrder.fundNameSnapshot) ??
            _normalizedOptionalString(fund.fundName) ??
            _fallbackFundName;
        final fundCodeSnapshot =
            _normalizedOptionalString(purchaseOrder.fundCodeSnapshot) ??
            _normalizedOptionalString(fund.fundCode);
        final ledgerType = _ledgerTypeForDelta(normalizedDelta);
        final ledgerAmount = _ledgerAmountForDelta(normalizedDelta);
        final ledgerItemName = 'Purchase Order $purchaseOrderDisplayNumber';

        if (updatedAvailableAmount != null) {
          transaction.update(fundRef, {
            'availableAmount': updatedAvailableAmount,
            'updatedAt': serverTimestamp,
          });
        }

        transaction.update(purchaseOrderRef, {
          'actualTotal': normalizedActualTotal,
          'reconciledDeltaAmount': normalizedDelta,
          'actualCostRecordedBy': cleanReconciledBy,
          'actualCostRecordedAt': serverTimestamp,
          'costReconciled': true,
          'costReconciledBy': cleanReconciledBy,
          'costReconciledAt': serverTimestamp,
          'fundTransactionId': ledgerDocumentId,
          'status': _completedStatus,
          'updatedAt': serverTimestamp,
        });

        for (final orderRef in orderRefs) {
          transaction.update(orderRef, {
            'purchaseOrderStatus': _completedStatus,
            'actualTotal': null,
            'actualCostRecordedBy': null,
            'actualCostRecordedAt': null,
            'costReconciled': false,
            'costReconciledAt': null,
            'costReconciledBy': null,
            'reconciledDeltaAmount': null,
          });
        }

        final ledgerTransaction = FundTransactionModel(
          id: ledgerDocumentId,
          labId: cleanLabId,
          fundId: cleanFundId,
          requirementId: '',
          type: ledgerType,
          status: FundTransactionModel.statusActive,
          amount: ledgerAmount,
          itemNameSnapshot: ledgerItemName,
          fundNameSnapshot: fundNameSnapshot,
          fundCodeSnapshot: fundCodeSnapshot,
          purchaseOrderId: cleanPurchaseOrderId,
          purchaseOrderNumber: purchaseOrderDisplayNumber,
          createdBy: cleanReconciledBy,
          createdAt: null,
          notes: _buildPurchaseOrderReconciliationNote(
            actualTotal: normalizedActualTotal,
            allocatedTotal: normalizedAllocatedTotal,
            delta: normalizedDelta,
          ),
        );

        final ledgerData = ledgerTransaction.toFirestore();
        ledgerData['createdAt'] = serverTimestamp;
        transaction.set(ledgerRef, ledgerData);
      });
    });
  }

  Future<T> _runGuarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      if (FirestoreAccessGuard.isPermissionDenied(error)) {
        throw const LabDataAccessException();
      }
      rethrow;
    }
  }

  int _comparePurchaseOrders(PurchaseOrderModel a, PurchaseOrderModel b) {
    final aCreatedAt = a.createdAt;
    final bCreatedAt = b.createdAt;

    if (aCreatedAt != null && bCreatedAt != null) {
      final createdAtComparison = bCreatedAt.compareTo(aCreatedAt);
      if (createdAtComparison != 0) {
        return createdAtComparison;
      }
    } else if (aCreatedAt == null && bCreatedAt != null) {
      return 1;
    } else if (aCreatedAt != null && bCreatedAt == null) {
      return -1;
    }

    return a.id.toLowerCase().compareTo(b.id.toLowerCase());
  }

  String _validatedLabId(String labId) {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      throw ArgumentError('Lab ID is required.');
    }
    return cleanLabId;
  }

  String _validatedCreatedBy(String createdBy) {
    final cleanCreatedBy = createdBy.trim();
    if (cleanCreatedBy.isEmpty) {
      throw ArgumentError('User identity is required.');
    }
    return cleanCreatedBy;
  }

  String _validatedPurchaseOrderId(String purchaseOrderId) {
    final cleanPurchaseOrderId = purchaseOrderId.trim();
    if (cleanPurchaseOrderId.isEmpty) {
      throw ArgumentError('Purchase Order ID is required.');
    }
    return cleanPurchaseOrderId;
  }

  double _validatedActualTotal(double actualTotal) {
    if (!actualTotal.isFinite || actualTotal <= 0) {
      throw ArgumentError(
        'Actual Purchase Order total must be greater than zero.',
      );
    }

    final normalizedActualTotal = _normalizeCurrency(actualTotal);
    if (!normalizedActualTotal.isFinite || normalizedActualTotal <= 0) {
      throw ArgumentError(
        'Actual Purchase Order total must be greater than zero.',
      );
    }

    return normalizedActualTotal;
  }

  List<String> _validatedOrderIds(List<String> orderIds) {
    if (orderIds.isEmpty) {
      throw ArgumentError('Select at least one order.');
    }

    final uniqueOrderIds = <String>[];
    final seenOrderIds = <String>{};

    for (final orderId in orderIds) {
      final cleanOrderId = orderId.trim();
      if (cleanOrderId.isEmpty) {
        throw ArgumentError('One or more selected order IDs are invalid.');
      }

      if (seenOrderIds.add(cleanOrderId)) {
        uniqueOrderIds.add(cleanOrderId);
      }
    }

    if (uniqueOrderIds.isEmpty) {
      throw ArgumentError('Select at least one order.');
    }

    if (uniqueOrderIds.length > _maxOrdersPerPurchaseOrder) {
      throw ArgumentError(
        'A Purchase Order can contain at most $_maxOrdersPerPurchaseOrder orders.',
      );
    }

    return uniqueOrderIds;
  }

  String? _normalizedOptionalString(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _buildFolderNumber(String purchaseOrderId) {
    final year = DateTime.now().toUtc().year;
    final compactId = purchaseOrderId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final suffix = compactId.isEmpty
        ? 'PO'
        : (compactId.length <= 6 ? compactId : compactId.substring(0, 6));
    return 'POF-$year-$suffix';
  }

  String _normalizedStatus(String value) {
    return value.trim().toLowerCase();
  }

  double _normalizeCurrency(double value) {
    final rounded = (value * 100).roundToDouble() / 100;
    if (rounded.abs() < _amountTolerance) {
      return 0;
    }
    return rounded;
  }

  bool _isAllowedReconciliationPurchaseOrderStatus(String status) {
    switch (status) {
      case _draftStatus:
      case _submittedStatus:
      case _processingStatus:
      case _completedStatus:
        return true;
      default:
        return false;
    }
  }

  String _purchaseOrderLedgerDocumentId(String purchaseOrderId) {
    return 'po_reconcile_$purchaseOrderId';
  }

  String _resolvedPurchaseOrderDisplayNumber(PurchaseOrderModel purchaseOrder) {
    final displayNumber = purchaseOrder.displayNumber.trim();
    if (displayNumber.isNotEmpty) {
      return displayNumber;
    }

    final folderNumber = purchaseOrder.folderNumber.trim();
    if (folderNumber.isNotEmpty) {
      return folderNumber;
    }

    return purchaseOrder.id.trim();
  }

  String _ledgerTypeForDelta(double delta) {
    if (delta > 0) {
      return _adjustmentTransactionType;
    }

    if (delta < 0) {
      return _refundTransactionType;
    }

    return _reconciliationTransactionType;
  }

  double _ledgerAmountForDelta(double delta) {
    if (delta < 0) {
      return _normalizeCurrency(delta.abs());
    }

    return _normalizeCurrency(delta);
  }

  String _buildPurchaseOrderReconciliationNote({
    required double actualTotal,
    required double allocatedTotal,
    required double delta,
  }) {
    final formattedActualTotal = _formatAmountForNote(actualTotal);
    final formattedAllocatedTotal = _formatAmountForNote(allocatedTotal);

    if (delta > 0) {
      return 'Actual Purchase Order cost $formattedActualTotal exceeded allocated total $formattedAllocatedTotal.';
    }

    if (delta < 0) {
      return 'Actual Purchase Order cost $formattedActualTotal was below allocated total $formattedAllocatedTotal.';
    }

    return 'Actual Purchase Order cost matched the allocated total of $formattedAllocatedTotal.';
  }

  String _formatAmountForNote(double value) {
    final normalizedValue = _normalizeCurrency(value);
    final fixedValue = normalizedValue.toStringAsFixed(2);
    final parts = fixedValue.split('.');
    final integerPart = parts.first;
    final decimalPart = parts.length > 1 ? parts[1] : '00';
    final groupedIntegerPart = _formatIndianDigits(integerPart);

    if (decimalPart == '00') {
      return '\u20B9$groupedIntegerPart';
    }

    return '\u20B9$groupedIntegerPart.$decimalPart';
  }

  String _formatIndianDigits(String digits) {
    if (digits.length <= 3) {
      return digits;
    }

    final lastThreeDigits = digits.substring(digits.length - 3);
    var leadingDigits = digits.substring(0, digits.length - 3);
    final groups = <String>[];

    while (leadingDigits.length > 2) {
      groups.insert(0, leadingDigits.substring(leadingDigits.length - 2));
      leadingDigits = leadingDigits.substring(0, leadingDigits.length - 2);
    }

    if (leadingDigits.isNotEmpty) {
      groups.insert(0, leadingDigits);
    }

    return '${groups.join(',')},$lastThreeDigits';
  }

  String? _deriveSharedNonEmptyValue(Iterable<String> values) {
    String? sharedValue;

    for (final value in values) {
      final cleanValue = _normalizedOptionalString(value);
      if (cleanValue == null) {
        return null;
      }

      if (sharedValue == null) {
        sharedValue = cleanValue;
        continue;
      }

      if (sharedValue != cleanValue) {
        return null;
      }
    }

    return sharedValue;
  }
}

class _ValidatedPurchaseOrderSource {
  const _ValidatedPurchaseOrderSource({
    required this.reference,
    required this.order,
  });

  final DocumentReference<Map<String, dynamic>> reference;
  final OrderModel order;
}
