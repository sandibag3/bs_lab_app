import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/fund_model.dart';
import '../models/fund_transaction_model.dart';
import '../models/requirement_model.dart';
import 'firestore_access_guard.dart';

class RequirementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const double _amountTolerance = 0.000001;
  static const String _statusChangedDeleteMessage =
      'This requirement can no longer be deleted because its status has changed.';

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _requirementsSnapshots() {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    if (appState.isDemoLabSelected) {
      return _firestore.collection('requirements').snapshots();
    }

    return _firestore
        .collection('requirements')
        .where('labId', isEqualTo: selectedLabId)
        .snapshots();
  }

  Future<String> addRequirement(RequirementModel req) async {
    final data = req.toMap();
    final createdBy = req.createdBy.trim().isNotEmpty
        ? req.createdBy.trim()
        : AppState.instance.authenticatedUserId.trim();
    if (createdBy.isNotEmpty) {
      data['createdBy'] = createdBy;
    }

    final doc = await _firestore.collection('requirements').add(data);
    return doc.id;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getRequirementDocsOnce() async {
    if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }

    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    final snapshot = appState.isDemoLabSelected
        ? await _firestore.collection('requirements').get()
        : await _firestore
              .collection('requirements')
              .where('labId', isEqualTo: selectedLabId)
              .get();

    if (appState.isDemoLabSelected) {
      return snapshot.docs
          .where((doc) => _matchesCurrentLab(doc.data()))
          .toList();
    }

    return snapshot.docs.toList();
  }

  Stream<List<RequirementModel>> getRequirements() {
    return FirestoreAccessGuard.guardLabStream<List<RequirementModel>>(
      source: _requirementsSnapshots(),
      emptyValue: <RequirementModel>[],
      onData: (snapshot) {
        final docs = AppState.instance.isDemoLabSelected
            ? snapshot.docs.where((doc) => _matchesCurrentLab(doc.data()))
            : snapshot.docs;

        final requirements = docs
            .map((doc) => RequirementModel.fromFirestore(doc))
            .toList();

        requirements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return requirements;
      },
    );
  }

  Future<void> updateRequirementStatus({
    required String docId,
    required String status,
    required String approvedBy,
  }) async {
    await _firestore.collection('requirements').doc(docId).update({
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': Timestamp.now(),
    });
  }

  Future<void> cancelPendingRequirement({
    required String requirementId,
    required String requesterUid,
    String? requesterUserName,
    String? requesterEmail,
  }) async {
    final cleanRequirementId = requirementId.trim();
    final cleanRequesterUid = requesterUid.trim();
    final cleanRequesterUserName = requesterUserName?.trim();
    final cleanRequesterEmail = requesterEmail?.trim();

    if (cleanRequirementId.isEmpty) {
      throw ArgumentError('Requirement ID is required.');
    }

    if (cleanRequesterUid.isEmpty) {
      throw ArgumentError('Requester identity is required.');
    }

    final requirementRef = _firestore
        .collection('requirements')
        .doc(cleanRequirementId);

    await _firestore.runTransaction((transaction) async {
      final requirementSnapshot = await transaction.get(requirementRef);
      final data = requirementSnapshot.data();

      if (!requirementSnapshot.exists || data == null) {
        throw StateError('Requirement could not be found.');
      }

      final rawStatus = (data['status'] ?? '').toString();
      if (_normalizedStatus(rawStatus) != 'pending') {
        throw StateError(_statusChangedDeleteMessage);
      }

      final approvedBy = _normalizedOptionalString(data['approvedBy']);
      if (approvedBy != null || data['approvedAt'] != null) {
        throw StateError(_statusChangedDeleteMessage);
      }

      if (!_matchesRequesterIdentity(
        data: data,
        requesterUid: cleanRequesterUid,
        requesterUserName: cleanRequesterUserName,
        requesterEmail: cleanRequesterEmail,
      )) {
        throw StateError('You can only delete your own pending requirements.');
      }

      transaction.update(requirementRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': cleanRequesterUid,
      });
    });
  }

  Future<void> approveRequirementWithFund({
    required String requirementId,
    required String labId,
    required String fundId,
    required String approvedBy,
  }) async {
    final cleanRequirementId = requirementId.trim();
    final cleanLabId = labId.trim();
    final cleanFundId = fundId.trim();
    final cleanApprovedBy = approvedBy.trim();

    if (cleanRequirementId.isEmpty) {
      throw ArgumentError('Requirement ID is required.');
    }

    if (cleanLabId.isEmpty) {
      throw ArgumentError('Lab ID is required.');
    }

    if (cleanFundId.isEmpty) {
      throw ArgumentError('Fund ID is required.');
    }

    if (cleanApprovedBy.isEmpty) {
      throw ArgumentError('Approver identity is required.');
    }

    final requirementRef = _firestore
        .collection('requirements')
        .doc(cleanRequirementId);
    final fundRef = _firestore
        .collection('labs')
        .doc(cleanLabId)
        .collection('funds')
        .doc(cleanFundId);
    final transactionRef = fundRef.collection('transactions').doc();

    await _firestore.runTransaction((transaction) async {
      final requirementSnapshot = await transaction.get(requirementRef);
      if (!requirementSnapshot.exists || requirementSnapshot.data() == null) {
        throw StateError('Requirement could not be found.');
      }

      final requirement = RequirementModel.fromFirestore(requirementSnapshot);
      if (requirement.labId.trim() != cleanLabId) {
        throw StateError('Requirement does not belong to the active lab.');
      }

      if (_normalizedStatus(requirement.status) != 'pending') {
        throw StateError('Only pending requirements can be approved.');
      }

      if (_hasExistingFundAllocation(requirement)) {
        throw StateError('This requirement already has a fund allocation.');
      }

      final allocatedAmount = _parseAllocatedAmount(requirement.estimatedTotal);

      final fundSnapshot = await transaction.get(fundRef);
      if (!fundSnapshot.exists || fundSnapshot.data() == null) {
        throw StateError('Fund could not be found.');
      }

      final fund = FundModel.fromFirestore(fundSnapshot);
      if (fund.labId.trim() != cleanLabId) {
        throw StateError('Fund does not belong to the active lab.');
      }

      if (fund.effectiveStatus != FundModel.statusActive) {
        throw StateError('Only active funds can be used for approval.');
      }

      if (!fund.availableAmount.isFinite) {
        throw StateError(
          'This fund does not have sufficient available balance.',
        );
      }

      final newAvailableAmount = fund.availableAmount - allocatedAmount;
      if (newAvailableAmount < -_amountTolerance) {
        throw StateError(
          'This fund does not have sufficient available balance.',
        );
      }

      final normalizedAvailableAmount = _normalizeAvailableBalance(
        newAvailableAmount,
      );
      final fundNameSnapshot = _normalizedOptionalString(fund.fundName);
      final fundCodeSnapshot = _normalizedOptionalString(fund.fundCode);
      final itemNameSnapshot = _buildRequirementItemSnapshot(requirement);
      final serverTimestamp = FieldValue.serverTimestamp();

      transaction.update(fundRef, {
        'availableAmount': normalizedAvailableAmount,
        'updatedAt': serverTimestamp,
      });

      transaction.update(requirementRef, {
        'status': 'approved',
        'approvedBy': cleanApprovedBy,
        'approvedAt': serverTimestamp,
        'fundId': cleanFundId,
        'fundNameSnapshot': fundNameSnapshot,
        'fundCodeSnapshot': fundCodeSnapshot,
        'allocatedAmount': allocatedAmount,
        'fundAllocatedBy': cleanApprovedBy,
        'fundAllocatedAt': serverTimestamp,
        'fundTransactionId': transactionRef.id,
      });

      transaction.set(transactionRef, {
        'labId': cleanLabId,
        'fundId': cleanFundId,
        'requirementId': cleanRequirementId,
        'type': FundTransactionModel.typeAllocation,
        'status': FundTransactionModel.statusActive,
        'amount': allocatedAmount,
        'itemNameSnapshot': itemNameSnapshot,
        'fundNameSnapshot': fundNameSnapshot,
        'fundCodeSnapshot': fundCodeSnapshot,
        'createdBy': cleanApprovedBy,
        'createdAt': serverTimestamp,
        'notes': null,
      });
    });
  }

  Future<void> markRequirementOrdered({
    required String docId,
    required String updatedBy,
  }) async {
    await _firestore.collection('requirements').doc(docId).update({
      'status': 'ordered',
      'approvedBy': updatedBy,
      'approvedAt': Timestamp.now(),
    });
  }

  static String _normalizedStatus(String value) {
    return value.trim().toLowerCase();
  }

  static bool _matchesRequesterIdentity({
    required Map<String, dynamic> data,
    required String requesterUid,
    String? requesterUserName,
    String? requesterEmail,
  }) {
    final storedRequesterUid =
        _normalizedOptionalString(data['createdBy']) ??
        _normalizedOptionalString(data['requestedBy']) ??
        _normalizedOptionalString(data['requesterId']) ??
        _normalizedOptionalString(data['userId']);

    if (storedRequesterUid != null) {
      return storedRequesterUid == requesterUid;
    }

    final storedUserName = _normalizedOptionalString(data['userName']);
    if (storedUserName == null) {
      return false;
    }

    return _matchesLegacyIdentity(storedUserName, requesterUserName) ||
        _matchesLegacyIdentity(storedUserName, requesterEmail);
  }

  static bool _matchesLegacyIdentity(String storedValue, String? candidate) {
    final normalizedCandidate = candidate?.trim().toLowerCase();
    if (normalizedCandidate == null || normalizedCandidate.isEmpty) {
      return false;
    }

    return storedValue.trim().toLowerCase() == normalizedCandidate;
  }

  static bool _hasExistingFundAllocation(RequirementModel requirement) {
    if (requirement.hasFundAllocation) {
      return true;
    }

    final hasFundId = (requirement.fundId?.trim() ?? '').isNotEmpty;
    final hasTransactionId =
        (requirement.fundTransactionId?.trim() ?? '').isNotEmpty;
    final hasAmount = requirement.allocatedAmount != null;

    return hasFundId || hasTransactionId || hasAmount;
  }

  static double _parseAllocatedAmount(String estimatedTotal) {
    var cleaned = estimatedTotal.trim();
    if (cleaned.isEmpty) {
      throw StateError(
        'A valid estimated total greater than zero is required before approval.',
      );
    }

    cleaned = cleaned.replaceAll(',', '').trim();
    cleaned = cleaned
        .replaceFirst(RegExp('^(?:\\u20B9|\\u00E2\\u201A\\u00B9)\\s*'), '')
        .trim();
    if (cleaned.startsWith('₹')) {
      cleaned = cleaned.substring(1).trim();
    } else if (cleaned.startsWith('â‚¹')) {
      cleaned = cleaned.substring('â‚¹'.length).trim();
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      throw StateError(
        'A valid estimated total greater than zero is required before approval.',
      );
    }

    final rounded = _roundCurrency(parsed);
    if (!rounded.isFinite || rounded <= 0) {
      throw StateError(
        'A valid estimated total greater than zero is required before approval.',
      );
    }

    return rounded;
  }

  static double _roundCurrency(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  static double _normalizeAvailableBalance(double value) {
    final rounded = _roundCurrency(value);
    if (rounded.abs() < _amountTolerance) {
      return 0;
    }

    return rounded;
  }

  static String _buildRequirementItemSnapshot(RequirementModel requirement) {
    final chemicalName = requirement.chemicalName.trim();
    if (chemicalName.isNotEmpty) {
      return chemicalName;
    }

    final consumableType = requirement.consumableType.trim();
    if (consumableType.isNotEmpty) {
      return consumableType;
    }

    final mainType = requirement.mainType.trim();
    if (mainType.isNotEmpty) {
      return mainType;
    }

    return 'Requirement';
  }

  static String? _normalizedOptionalString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
