import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fund_model.dart';
import '../models/fund_transaction_model.dart';
import 'firestore_access_guard.dart';

class FundService {
  static const double _amountTolerance = 0.000001;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _fundsRef(String labId) {
    return _firestore.collection('labs').doc(labId).collection('funds');
  }

  CollectionReference<Map<String, dynamic>> _transactionsRef({
    required String labId,
    required String fundId,
  }) {
    return _fundsRef(labId).doc(fundId).collection('transactions');
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

  Stream<List<FundModel>> _guardedFundsStream({
    required String labId,
    required Stream<QuerySnapshot<Map<String, dynamic>>> source,
    required List<FundModel> Function(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    )
    onData,
  }) {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return Stream<List<FundModel>>.value(<FundModel>[]);
    }

    return source.transform(
      StreamTransformer<
        QuerySnapshot<Map<String, dynamic>>,
        List<FundModel>
      >.fromHandlers(
        handleData: (snapshot, sink) {
          sink.add(onData(snapshot));
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

  Stream<List<FundModel>> streamFunds(String labId) {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return Stream<List<FundModel>>.value(<FundModel>[]);
    }

    return _guardedFundsStream(
      labId: cleanLabId,
      source: _fundsRef(cleanLabId).snapshots(),
      onData: (snapshot) {
        final funds = snapshot.docs.map(FundModel.fromFirestore).toList();
        funds.sort(_compareFunds);
        return funds;
      },
    );
  }

  Stream<List<FundTransactionModel>> streamFundTransactions({
    required String labId,
    required String fundId,
  }) {
    final cleanLabId = labId.trim();
    final cleanFundId = fundId.trim();
    if (cleanLabId.isEmpty || cleanFundId.isEmpty) {
      return Stream<List<FundTransactionModel>>.value(
        const <FundTransactionModel>[],
      );
    }

    return _transactionsRef(
      labId: cleanLabId,
      fundId: cleanFundId,
    ).snapshots().transform(
      StreamTransformer<
        QuerySnapshot<Map<String, dynamic>>,
        List<FundTransactionModel>
      >.fromHandlers(
        handleData: (snapshot, sink) {
          final transactions = snapshot.docs
              .map(FundTransactionModel.fromFirestore)
              .toList();
          transactions.sort(_compareTransactions);
          sink.add(transactions);
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

  Future<void> addFund({required String labId, required FundModel fund}) async {
    await _runGuarded(() async {
      final cleanLabId = _validatedLabId(labId);
      final cleanFundName = _validatedFundName(fund.fundName);
      final cleanTotalAmount = _validatedPositiveAmount(
        fund.totalAmount,
        message: 'Total amount must be greater than zero.',
      );
      final cleanFundCode = _normalizedOptionalString(fund.fundCode);
      final cleanNotes = _normalizedOptionalString(fund.notes);

      _validateDateRange(startDate: fund.startDate, endDate: fund.endDate);

      final docRef = _fundsRef(cleanLabId).doc();
      await docRef.set({
        'labId': cleanLabId,
        'fundName': cleanFundName,
        'fundCode': cleanFundCode,
        'totalAmount': cleanTotalAmount,
        'availableAmount': cleanTotalAmount,
        'startDate': Timestamp.fromDate(fund.startDate),
        'endDate': Timestamp.fromDate(fund.endDate),
        'notes': cleanNotes,
        'status': FundModel.statusActive,
        'createdBy': fund.createdBy.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateFund({
    required String labId,
    required FundModel fund,
  }) async {
    await _runGuarded(() async {
      final cleanLabId = _validatedLabId(labId);
      final cleanFundId = fund.id.trim();
      if (cleanFundId.isEmpty) {
        throw ArgumentError('Fund ID is required.');
      }

      final docRef = _fundsRef(cleanLabId).doc(cleanFundId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        throw StateError('Fund could not be found.');
      }

      final currentFund = FundModel.fromFirestore(snapshot);
      final cleanFundName = _validatedFundName(fund.fundName);
      final cleanTotalAmount = _validatedPositiveAmount(
        fund.totalAmount,
        message: 'Total amount must be greater than zero.',
      );
      final cleanFundCode = _normalizedOptionalString(fund.fundCode);
      final cleanNotes = _normalizedOptionalString(fund.notes);

      _validateFiniteAmount(
        fund.availableAmount,
        message: 'Available amount must be a valid number.',
      );
      _validateDateRange(startDate: fund.startDate, endDate: fund.endDate);

      final proposedAvailableAmount =
          currentFund.availableAmount +
          (cleanTotalAmount - currentFund.totalAmount);
      if (proposedAvailableAmount < -_amountTolerance) {
        throw StateError(
          'The total amount cannot be lower than the amount already utilized.',
        );
      }

      final cleanAvailableAmount = _normalizedAmount(proposedAvailableAmount);

      await docRef.update({
        'fundName': cleanFundName,
        'fundCode': cleanFundCode,
        'totalAmount': cleanTotalAmount,
        'availableAmount': cleanAvailableAmount,
        'startDate': Timestamp.fromDate(fund.startDate),
        'endDate': Timestamp.fromDate(fund.endDate),
        'notes': cleanNotes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> closeFund({
    required String labId,
    required String fundId,
  }) async {
    await _runGuarded(() async {
      final cleanLabId = _validatedLabId(labId);
      final cleanFundId = fundId.trim();
      if (cleanFundId.isEmpty) {
        throw ArgumentError('Fund ID is required.');
      }

      try {
        await _fundsRef(cleanLabId).doc(cleanFundId).update({
          'status': FundModel.statusClosed,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (error) {
        if (error.code.trim().toLowerCase() == 'not-found') {
          throw StateError('Fund could not be found.');
        }
        rethrow;
      }
    });
  }

  int _compareFunds(FundModel a, FundModel b) {
    final statusComparison = _statusRank(
      a.effectiveStatus,
    ).compareTo(_statusRank(b.effectiveStatus));
    if (statusComparison != 0) {
      return statusComparison;
    }

    final startDateComparison = b.startDate.compareTo(a.startDate);
    if (startDateComparison != 0) {
      return startDateComparison;
    }

    final nameComparison = a.fundName.toLowerCase().compareTo(
      b.fundName.toLowerCase(),
    );
    if (nameComparison != 0) {
      return nameComparison;
    }

    return a.id.toLowerCase().compareTo(b.id.toLowerCase());
  }

  int _statusRank(String effectiveStatus) {
    switch (effectiveStatus) {
      case FundModel.statusClosed:
        return 2;
      case FundModel.statusExpired:
        return 1;
      case FundModel.statusActive:
      default:
        return 0;
    }
  }

  int _compareTransactions(
    FundTransactionModel a,
    FundTransactionModel b,
  ) {
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

  String _validatedFundName(String fundName) {
    final cleanFundName = fundName.trim();
    if (cleanFundName.isEmpty) {
      throw ArgumentError('Fund name is required.');
    }
    return cleanFundName;
  }

  double _validatedPositiveAmount(double value, {required String message}) {
    _validateFiniteAmount(value, message: message);
    if (value <= 0) {
      throw ArgumentError(message);
    }
    return value;
  }

  void _validateFiniteAmount(double value, {required String message}) {
    if (!value.isFinite) {
      throw ArgumentError(message);
    }
  }

  void _validateDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError('End date cannot be before start date.');
    }
  }

  String? _normalizedOptionalString(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  double _normalizedAmount(double value) {
    if (value.abs() < _amountTolerance) {
      return 0;
    }
    return value;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
