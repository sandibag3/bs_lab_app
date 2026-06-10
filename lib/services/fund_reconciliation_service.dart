import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fund_model.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';

class FundReconciliationService {
  static const double _amountTolerance = 0.000001;
  static const String _ledgerStatusActive = 'active';
  static const String _ledgerTypeAdjustment = 'adjustment';
  static const String _ledgerTypeRefund = 'refund';
  static const String _ledgerTypeReconciliation = 'reconciliation';

  FundReconciliationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> reconcileOrderActualCost({
    required String orderId,
    required String labId,
    required double actualTotal,
    required String reconciledBy,
  }) async {
    final cleanOrderId = orderId.trim();
    final cleanLabId = labId.trim();
    final cleanReconciledBy = reconciledBy.trim();

    if (cleanOrderId.isEmpty) {
      throw ArgumentError('Order ID is required.');
    }
    if (cleanLabId.isEmpty) {
      throw ArgumentError('Lab ID is required.');
    }
    if (cleanReconciledBy.isEmpty) {
      throw ArgumentError('User identity is required.');
    }
    if (!actualTotal.isFinite || actualTotal <= 0) {
      throw ArgumentError('Actual total must be greater than zero.');
    }

    final normalizedActualTotal = _normalizeCurrency(actualTotal);
    if (normalizedActualTotal <= 0) {
      throw ArgumentError('Actual total must be greater than zero.');
    }

    final orderRef = _firestore.collection('orders').doc(cleanOrderId);
    final requirementsRef = _firestore.collection('requirements');

    await _firestore.runTransaction((transaction) async {
      final orderSnapshot = await transaction.get(orderRef);
      if (!orderSnapshot.exists || orderSnapshot.data() == null) {
        throw StateError('Order could not be found.');
      }

      final order = OrderModel.fromFirestore(orderSnapshot);
      if (order.labId.trim() != cleanLabId) {
        throw StateError('Order does not belong to the active lab.');
      }

      final cleanRequirementId = order.requirementId.trim();
      if (cleanRequirementId.isEmpty) {
        throw StateError('This order is not linked to a requirement.');
      }

      if (_normalizedStatus(order.status) != 'delivered') {
        throw StateError('Only delivered orders can be reconciled.');
      }

      if (order.costReconciled ||
          (order.fundAdjustmentTransactionId?.trim() ?? '').isNotEmpty) {
        throw StateError('This order has already been reconciled.');
      }

      final requirementRef = requirementsRef.doc(cleanRequirementId);
      final requirementSnapshot = await transaction.get(requirementRef);
      if (!requirementSnapshot.exists || requirementSnapshot.data() == null) {
        throw StateError('Source requirement could not be found.');
      }

      final requirement = RequirementModel.fromFirestore(requirementSnapshot);
      if (requirement.labId.trim() != cleanLabId) {
        throw StateError('Requirement does not belong to the active lab.');
      }

      final cleanFundId = requirement.fundId?.trim() ?? '';
      final cleanFundTransactionId =
          requirement.fundTransactionId?.trim() ?? '';
      final allocatedAmount = requirement.allocatedAmount;

      if (cleanFundId.isEmpty ||
          cleanFundTransactionId.isEmpty ||
          allocatedAmount == null ||
          !allocatedAmount.isFinite ||
          allocatedAmount <= 0) {
        throw StateError('This requirement has no valid fund allocation.');
      }

      final normalizedAllocatedAmount = _normalizeCurrency(allocatedAmount);
      if (normalizedAllocatedAmount <= 0) {
        throw StateError('This requirement has no valid fund allocation.');
      }

      final fundRef = _firestore
          .collection('labs')
          .doc(cleanLabId)
          .collection('funds')
          .doc(cleanFundId);
      final fundSnapshot = await transaction.get(fundRef);
      if (!fundSnapshot.exists || fundSnapshot.data() == null) {
        throw StateError('Fund could not be found.');
      }

      final fund = FundModel.fromFirestore(fundSnapshot);
      if (fund.effectiveStatus == FundModel.statusClosed) {
        throw StateError('Closed funds cannot be reconciled.');
      }
      if (!fund.availableAmount.isFinite) {
        throw StateError('Fund available balance is invalid.');
      }

      final reconciliationRef = fundRef
          .collection('transactions')
          .doc('reconcile_$cleanOrderId');
      final reconciliationSnapshot = await transaction.get(reconciliationRef);
      if (reconciliationSnapshot.exists) {
        throw StateError('This order has already been reconciled.');
      }

      final normalizedAvailableAmount = _normalizeCurrency(
        fund.availableAmount,
      );
      final normalizedDelta = _normalizeCurrency(
        normalizedActualTotal - normalizedAllocatedAmount,
      );
      final absoluteDelta = _normalizeCurrency(normalizedDelta.abs());

      double? updatedAvailableAmount;
      if (normalizedDelta > 0) {
        final candidateAmount = _normalizeCurrency(
          normalizedAvailableAmount - normalizedDelta,
        );
        if (candidateAmount < -_amountTolerance) {
          throw StateError(
            'This fund does not have sufficient available balance for the additional cost.',
          );
        }
        updatedAvailableAmount = _normalizeCurrency(candidateAmount);
      } else if (normalizedDelta < 0) {
        updatedAvailableAmount = _normalizeCurrency(
          normalizedAvailableAmount + absoluteDelta,
        );
      }

      final fundNameSnapshot = _firstNonEmpty(
        requirement.fundNameSnapshot,
        fund.fundName,
      );
      final fundCodeSnapshot = _firstNonEmpty(
        requirement.fundCodeSnapshot,
        fund.fundCode,
      );
      final itemNameSnapshot = _buildItemSnapshot(order);
      final ledgerType = _ledgerTypeForDelta(normalizedDelta);
      final serverTimestamp = FieldValue.serverTimestamp();

      if (updatedAvailableAmount != null) {
        transaction.update(fundRef, {
          'availableAmount': updatedAvailableAmount,
          'updatedAt': serverTimestamp,
        });
      }

      transaction.update(orderRef, {
        'actualTotal': normalizedActualTotal,
        'actualCostRecordedBy': cleanReconciledBy,
        'actualCostRecordedAt': serverTimestamp,
        'costReconciled': true,
        'costReconciledAt': serverTimestamp,
        'costReconciledBy': cleanReconciledBy,
        'fundAdjustmentTransactionId': reconciliationRef.id,
        'reconciledDeltaAmount': normalizedDelta,
      });

      transaction.set(reconciliationRef, {
        'labId': cleanLabId,
        'fundId': cleanFundId,
        'requirementId': cleanRequirementId,
        'type': ledgerType,
        'status': _ledgerStatusActive,
        'amount': absoluteDelta,
        'itemNameSnapshot': itemNameSnapshot,
        'fundNameSnapshot': fundNameSnapshot,
        'fundCodeSnapshot': fundCodeSnapshot,
        'createdBy': cleanReconciledBy,
        'createdAt': serverTimestamp,
        'notes': _buildReconciliationNote(
          actualTotal: normalizedActualTotal,
          allocatedAmount: normalizedAllocatedAmount,
          delta: normalizedDelta,
        ),
      });
    });
  }

  String _ledgerTypeForDelta(double delta) {
    if (delta > 0) {
      return _ledgerTypeAdjustment;
    }
    if (delta < 0) {
      return _ledgerTypeRefund;
    }
    return _ledgerTypeReconciliation;
  }

  String _buildItemSnapshot(OrderModel order) {
    final chemicalName = order.chemicalName.trim();
    if (chemicalName.isNotEmpty) {
      return chemicalName;
    }

    final consumableType = order.consumableType.trim();
    if (consumableType.isNotEmpty) {
      return consumableType;
    }

    final mainType = order.mainType.trim();
    if (mainType.isNotEmpty) {
      return mainType;
    }

    return 'Order reconciliation';
  }

  String _buildReconciliationNote({
    required double actualTotal,
    required double allocatedAmount,
    required double delta,
  }) {
    final actualText = _formatMoneyForNote(actualTotal);
    final allocatedText = _formatMoneyForNote(allocatedAmount);

    if (delta > 0) {
      return 'Actual cost $actualText exceeded allocated amount $allocatedText.';
    }
    if (delta < 0) {
      return 'Actual cost $actualText was below allocated amount $allocatedText.';
    }
    return 'Actual cost matched the allocated amount of $allocatedText.';
  }

  String _formatMoneyForNote(double value) {
    final normalized = _normalizeCurrency(value);
    final absoluteValue = normalized.abs();
    final fixed = absoluteValue.toStringAsFixed(2);
    final parts = fixed.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';
    final groupedInteger = _formatIndianDigits(integerPart);
    final amountText = decimalPart == '00'
        ? groupedInteger
        : '$groupedInteger.$decimalPart';
    final prefix = normalized < 0 ? '-Rs ' : 'Rs ';
    return '$prefix$amountText';
  }

  String _formatIndianDigits(String digits) {
    if (digits.length <= 3) {
      return digits;
    }

    final lastThree = digits.substring(digits.length - 3);
    var leading = digits.substring(0, digits.length - 3);
    final parts = <String>[];

    while (leading.length > 2) {
      parts.insert(0, leading.substring(leading.length - 2));
      leading = leading.substring(0, leading.length - 2);
    }

    if (leading.isNotEmpty) {
      parts.insert(0, leading);
    }

    return '${parts.join(',')},$lastThree';
  }

  String? _firstNonEmpty(String? primary, String? fallback) {
    final cleanPrimary = primary?.trim() ?? '';
    if (cleanPrimary.isNotEmpty) {
      return cleanPrimary;
    }

    final cleanFallback = fallback?.trim() ?? '';
    if (cleanFallback.isNotEmpty) {
      return cleanFallback;
    }

    return null;
  }

  double _normalizeCurrency(double value) {
    final rounded = (value * 100).roundToDouble() / 100;
    if (rounded.abs() < _amountTolerance) {
      return 0;
    }
    return rounded;
  }

  String _normalizedStatus(String status) {
    return status.trim().toLowerCase();
  }
}
