import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/requirement_model.dart';
import 'firestore_access_guard.dart';

class RequirementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final doc = await _firestore.collection('requirements').add(req.toMap());
    return doc.id;
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
}
