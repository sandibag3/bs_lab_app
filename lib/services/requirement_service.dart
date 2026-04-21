import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/requirement_model.dart';

class RequirementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Future<void> addRequirement(RequirementModel req) async {
    await _firestore.collection('requirements').add(req.toMap());
  }

  Stream<List<RequirementModel>> getRequirements() {
    return _firestore
        .collection('requirements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) => _matchesCurrentLab(doc.data()))
          .map((doc) => RequirementModel.fromFirestore(doc))
          .toList();
    });
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
