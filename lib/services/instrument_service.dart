import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';
import '../models/instrument_model.dart';
import 'firestore_access_guard.dart';

class InstrumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _instrumentsRef =>
      _firestore.collection('instruments');

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

  Stream<QuerySnapshot<Map<String, dynamic>>> _instrumentSnapshots() {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    if (appState.isDemoLabSelected) {
      return _instrumentsRef.snapshots();
    }

    return _instrumentsRef.where('labId', isEqualTo: selectedLabId).snapshots();
  }

  Stream<List<InstrumentModel>> getInstruments() {
    return FirestoreAccessGuard.guardLabStream<List<InstrumentModel>>(
      source: _instrumentSnapshots(),
      emptyValue: <InstrumentModel>[],
      onData: (snapshot) {
        final docs = AppState.instance.isDemoLabSelected
            ? snapshot.docs.where((doc) => _matchesCurrentLab(doc.data()))
            : snapshot.docs;

        final instruments = docs.map(InstrumentModel.fromFirestore).toList();
        instruments.sort((a, b) {
          final categoryComparison = a.normalizedCategory
              .toLowerCase()
              .compareTo(b.normalizedCategory.toLowerCase());
          if (categoryComparison != 0) {
            return categoryComparison;
          }

          return a.normalizedName
              .toLowerCase()
              .compareTo(b.normalizedName.toLowerCase());
        });
        return instruments;
      },
    );
  }

  Future<String> addInstrument(InstrumentModel instrument) async {
    return _runGuarded(() async {
      final doc = await _instrumentsRef.add({
        ...instrument.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    });
  }
}
