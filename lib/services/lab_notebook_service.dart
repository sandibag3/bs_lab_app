import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/experiment_note_model.dart';
import '../models/notebook_experiment_model.dart';
import '../models/notebook_project_model.dart';
import 'firestore_access_guard.dart';

const List<String> notebookExperimentStatuses = [
  'Planned',
  'Running',
  'Workup pending',
  'Purification pending',
  'Completed',
  'Failed',
  'Repeated',
  'Optimized',
];

class LabNotebookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _projectsRef(String labId) {
    return _firestore
        .collection('labs')
        .doc(labId)
        .collection('notebookProjects');
  }

  CollectionReference<Map<String, dynamic>> _experimentsRef(
    String labId,
    String projectId,
  ) {
    return _projectsRef(labId).doc(projectId).collection('experiments');
  }

  DocumentReference<Map<String, dynamic>> _experimentRef(
    String labId,
    String projectId,
    String experimentId,
  ) {
    return _experimentsRef(labId, projectId).doc(experimentId);
  }

  CollectionReference<Map<String, dynamic>> _notesRef(
    String labId,
    String projectId,
    String experimentId,
  ) {
    return _experimentRef(labId, projectId, experimentId).collection('notes');
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

  StreamTransformer<S, T> _guardedTransformer<S, T>({
    required T Function(S value) onData,
  }) {
    return StreamTransformer<S, T>.fromHandlers(
      handleData: (value, sink) {
        sink.add(onData(value));
      },
      handleError: (error, stackTrace, sink) {
        if (FirestoreAccessGuard.isPermissionDenied(error)) {
          sink.addError(const LabDataAccessException(), stackTrace);
          return;
        }

        sink.addError(error, stackTrace);
      },
    );
  }

  Stream<List<NotebookProjectModel>> getProjects({required String labId}) {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return Stream<List<NotebookProjectModel>>.value(<NotebookProjectModel>[]);
    }

    return _projectsRef(cleanLabId).snapshots().transform(
      _guardedTransformer<
        QuerySnapshot<Map<String, dynamic>>,
        List<NotebookProjectModel>
      >(
        onData: (snapshot) {
          final projects = snapshot.docs
              .map(NotebookProjectModel.fromFirestore)
              .toList();
          projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return projects;
        },
      ),
    );
  }

  Stream<List<NotebookExperimentModel>> getExperiments({
    required String labId,
    required String projectId,
  }) {
    final cleanLabId = labId.trim();
    final cleanProjectId = projectId.trim();
    if (cleanLabId.isEmpty || cleanProjectId.isEmpty) {
      return Stream<List<NotebookExperimentModel>>.value(
        <NotebookExperimentModel>[],
      );
    }

    return _experimentsRef(cleanLabId, cleanProjectId).snapshots().transform(
      _guardedTransformer<
        QuerySnapshot<Map<String, dynamic>>,
        List<NotebookExperimentModel>
      >(
        onData: (snapshot) {
          final experiments = snapshot.docs
              .map(NotebookExperimentModel.fromFirestore)
              .toList();
          experiments.sort((a, b) {
            final dateComparison = b.date.compareTo(a.date);
            if (dateComparison != 0) {
              return dateComparison;
            }
            return b.createdAt.compareTo(a.createdAt);
          });
          return experiments;
        },
      ),
    );
  }

  Stream<NotebookExperimentModel?> getExperiment({
    required String labId,
    required String projectId,
    required String experimentId,
  }) {
    final cleanLabId = labId.trim();
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();

    if (cleanLabId.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty) {
      return Stream<NotebookExperimentModel?>.value(null);
    }

    return _experimentRef(
      cleanLabId,
      cleanProjectId,
      cleanExperimentId,
    ).snapshots().transform(
      _guardedTransformer<
        DocumentSnapshot<Map<String, dynamic>>,
        NotebookExperimentModel?
      >(
        onData: (snapshot) {
          if (!snapshot.exists) {
            return null;
          }

          return NotebookExperimentModel.fromFirestore(snapshot);
        },
      ),
    );
  }

  Stream<List<ExperimentNoteModel>> getExperimentNotes({
    required String labId,
    required String projectId,
    required String experimentId,
  }) {
    final cleanLabId = labId.trim();
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();

    if (cleanLabId.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty) {
      return Stream<List<ExperimentNoteModel>>.value(<ExperimentNoteModel>[]);
    }

    return _notesRef(
      cleanLabId,
      cleanProjectId,
      cleanExperimentId,
    ).snapshots().transform(
      _guardedTransformer<
        QuerySnapshot<Map<String, dynamic>>,
        List<ExperimentNoteModel>
      >(
        onData: (snapshot) {
          final notes = snapshot.docs
              .map(ExperimentNoteModel.fromFirestore)
              .toList();
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        },
      ),
    );
  }

  Future<String> addProject({required NotebookProjectModel project}) async {
    final cleanLabId = project.labId.trim();
    if (cleanLabId.isEmpty) {
      throw Exception('No lab selected.');
    }

    return _runGuarded(() async {
      final docRef = _projectsRef(cleanLabId).doc();
      await docRef.set(project.toMap());
      return docRef.id;
    });
  }

  Future<String> addExperiment({
    required NotebookExperimentModel experiment,
  }) async {
    final cleanLabId = experiment.labId.trim();
    final cleanProjectId = experiment.projectId.trim();

    if (cleanLabId.isEmpty || cleanProjectId.isEmpty) {
      throw Exception('Project or lab context is missing.');
    }

    return _runGuarded(() async {
      final docRef = _experimentsRef(cleanLabId, cleanProjectId).doc();
      await docRef.set(experiment.toMap());
      return docRef.id;
    });
  }

  Future<String> addExperimentNote({
    required String labId,
    required String projectId,
    required String experimentId,
    required ExperimentNoteModel note,
  }) async {
    final cleanLabId = labId.trim();
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();

    if (cleanLabId.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty) {
      throw Exception('Experiment context is missing.');
    }

    return _runGuarded(() async {
      final noteRef = _notesRef(
        cleanLabId,
        cleanProjectId,
        cleanExperimentId,
      ).doc();
      final batch = _firestore.batch();

      batch.set(noteRef, note.toMap());
      batch.update(
        _experimentRef(cleanLabId, cleanProjectId, cleanExperimentId),
        {'updatedAt': note.createdAt},
      );

      await batch.commit();
      return noteRef.id;
    });
  }

  Future<void> updateExperimentStatus({
    required String labId,
    required String projectId,
    required String experimentId,
    required String status,
  }) async {
    final cleanLabId = labId.trim();
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();
    final cleanStatus = status.trim();

    if (cleanLabId.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty ||
        cleanStatus.isEmpty) {
      throw Exception('Experiment status could not be updated.');
    }

    await _runGuarded(() async {
      await _experimentRef(
        cleanLabId,
        cleanProjectId,
        cleanExperimentId,
      ).update({'status': cleanStatus, 'updatedAt': Timestamp.now()});
    });
  }
}
