import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';
import '../models/glass_apparatus_model.dart';
import 'firestore_access_guard.dart';

class GlassApparatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _apparatusRef =>
      _firestore.collection('glass_apparatus');

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _apparatusSnapshots() {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    if (appState.isDemoLabSelected) {
      return _apparatusRef.snapshots();
    }

    return _apparatusRef.where('labId', isEqualTo: selectedLabId).snapshots();
  }

  Stream<List<GlassApparatusModel>> getApparatus() {
    return FirestoreAccessGuard.guardLabStream<List<GlassApparatusModel>>(
      source: _apparatusSnapshots(),
      emptyValue: <GlassApparatusModel>[],
      onData: (snapshot) {
        final docs = AppState.instance.isDemoLabSelected
            ? snapshot.docs.where((doc) => _matchesCurrentLab(doc.data()))
            : snapshot.docs;

        final apparatus = docs.map(GlassApparatusModel.fromFirestore).toList();
        apparatus.sort((a, b) {
          final categoryComparison = a.normalizedCategory
              .toLowerCase()
              .compareTo(b.normalizedCategory.toLowerCase());
          if (categoryComparison != 0) {
            return categoryComparison;
          }

          return a.normalizedName.toLowerCase().compareTo(
            b.normalizedName.toLowerCase(),
          );
        });
        return apparatus;
      },
    );
  }

  String createApparatusId() {
    return _apparatusRef.doc().id;
  }

  Future<String> addApparatus(GlassApparatusModel apparatus) async {
    return _runGuarded(() async {
      final explicitId = apparatus.id.trim();
      final doc = explicitId.isEmpty
          ? _apparatusRef.doc()
          : _apparatusRef.doc(explicitId);

      await doc.set({
        ...apparatus.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    });
  }

  Future<void> updateApparatus(GlassApparatusModel apparatus) async {
    await _runGuarded(() async {
      final cleanId = apparatus.id.trim();
      if (cleanId.isEmpty) {
        throw Exception('Apparatus id is missing.');
      }

      await _apparatusRef.doc(cleanId).update({
        'labId': apparatus.labId,
        'name': apparatus.name,
        'category': apparatus.normalizedCategory,
        'size': apparatus.size,
        'quantity': apparatus.quantity,
        'condition': apparatus.normalizedCondition,
        'location': apparatus.location,
        'incharge': apparatus.incharge,
        'notes': apparatus.notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteApparatus({required String docId}) async {
    await _runGuarded(() async {
      final cleanId = docId.trim();
      if (cleanId.isEmpty) {
        throw Exception('Apparatus id is missing.');
      }

      await _apparatusRef.doc(cleanId).delete();
    });
  }
}
