import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/experiment_edit_history_model.dart';
import '../models/experiment_note_model.dart';
import '../models/notebook_experiment_model.dart';
import '../models/notebook_project_model.dart';
import '../models/reaction_component_model.dart';
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
  static const String readOnlyMessage =
      "Read-only notebook view. You can only edit your own notebook.";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserUid => _auth.currentUser?.uid.trim() ?? '';
  String get currentUserEmail => _auth.currentUser?.email?.trim() ?? '';
  String get currentUserDisplayName =>
      _auth.currentUser?.displayName?.trim() ?? '';

  String resolveNotebookOwnerUid([String? notebookOwnerUid]) {
    final explicitOwnerUid = (notebookOwnerUid ?? '').trim();
    if (explicitOwnerUid.isNotEmpty) {
      return explicitOwnerUid;
    }

    return currentUserUid;
  }

  bool isReadOnly({String? notebookOwnerUid}) {
    final ownerUid = resolveNotebookOwnerUid(notebookOwnerUid);
    final userUid = currentUserUid;

    if (ownerUid.isEmpty && userUid.isEmpty) {
      return false;
    }

    if (ownerUid.isEmpty || userUid.isEmpty) {
      return true;
    }

    return userUid != ownerUid;
  }

  String _createdByValue() {
    final userUid = currentUserUid;
    if (userUid.isNotEmpty) {
      return userUid;
    }

    final userEmail = currentUserEmail;
    if (userEmail.isNotEmpty) {
      return userEmail;
    }

    final displayName = currentUserDisplayName;
    if (displayName.isNotEmpty) {
      return displayName;
    }

    return 'User';
  }

  String _nextDuplicateExperimentCode(
    String originalCode,
    Set<String> existingCodes,
  ) {
    final baseCode = originalCode.trim().isEmpty
        ? 'experiment'
        : originalCode.trim();

    var suffixIndex = 1;
    while (true) {
      final candidate = suffixIndex == 1
          ? '$baseCode-copy'
          : '$baseCode-copy-$suffixIndex';

      if (!existingCodes.contains(candidate.toLowerCase())) {
        return candidate;
      }

      suffixIndex += 1;
    }
  }

  Future<Set<String>> _existingExperimentCodes({
    required String labId,
    required String notebookOwnerUid,
    required String projectId,
  }) async {
    final existingSnapshot = await _experimentsRef(
      labId,
      notebookOwnerUid,
      projectId,
    ).get();

    return existingSnapshot.docs
        .map((doc) => (doc.data()['experimentCode'] ?? '').toString().trim())
        .where((code) => code.isNotEmpty)
        .map((code) => code.toLowerCase())
        .toSet();
  }

  CollectionReference<Map<String, dynamic>> _userNotebooksRef(String labId) {
    return _firestore.collection('labs').doc(labId).collection('userNotebooks');
  }

  CollectionReference<Map<String, dynamic>> _projectsRef(
    String labId,
    String notebookOwnerUid,
  ) {
    return _userNotebooksRef(
      labId,
    ).doc(notebookOwnerUid).collection('projects');
  }

  CollectionReference<Map<String, dynamic>> _experimentsRef(
    String labId,
    String notebookOwnerUid,
    String projectId,
  ) {
    return _projectsRef(
      labId,
      notebookOwnerUid,
    ).doc(projectId).collection('experiments');
  }

  DocumentReference<Map<String, dynamic>> _experimentRef(
    String labId,
    String notebookOwnerUid,
    String projectId,
    String experimentId,
  ) {
    return _experimentsRef(
      labId,
      notebookOwnerUid,
      projectId,
    ).doc(experimentId);
  }

  CollectionReference<Map<String, dynamic>> _notesRef(
    String labId,
    String notebookOwnerUid,
    String projectId,
    String experimentId,
  ) {
    return _experimentRef(
      labId,
      notebookOwnerUid,
      projectId,
      experimentId,
    ).collection('notes');
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

  void _ensureOwnerWriteAccess(String notebookOwnerUid) {
    final cleanOwnerUid = notebookOwnerUid.trim();
    final cleanCurrentUserUid = currentUserUid;

    if (cleanOwnerUid.isEmpty || cleanCurrentUserUid.isEmpty) {
      throw const LabDataAccessException(readOnlyMessage);
    }

    if (cleanOwnerUid != cleanCurrentUserUid) {
      throw const LabDataAccessException(readOnlyMessage);
    }
  }

  Stream<List<NotebookProjectModel>> getProjects({
    required String labId,
    String? notebookOwnerUid,
  }) {
    final cleanLabId = labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(notebookOwnerUid);
    if (cleanLabId.isEmpty || cleanNotebookOwnerUid.isEmpty) {
      return Stream<List<NotebookProjectModel>>.value(<NotebookProjectModel>[]);
    }

    return _projectsRef(
      cleanLabId,
      cleanNotebookOwnerUid,
    ).snapshots().transform(
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
    String? notebookOwnerUid,
  }) {
    final cleanLabId = labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(notebookOwnerUid);
    final cleanProjectId = projectId.trim();
    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty) {
      return Stream<List<NotebookExperimentModel>>.value(
        <NotebookExperimentModel>[],
      );
    }

    return _experimentsRef(
      cleanLabId,
      cleanNotebookOwnerUid,
      cleanProjectId,
    ).snapshots().transform(
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
    String? notebookOwnerUid,
  }) {
    final cleanLabId = labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(notebookOwnerUid);
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty) {
      return Stream<NotebookExperimentModel?>.value(null);
    }

    return _experimentRef(
      cleanLabId,
      cleanNotebookOwnerUid,
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
    String? notebookOwnerUid,
  }) {
    final cleanLabId = labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(notebookOwnerUid);
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty) {
      return Stream<List<ExperimentNoteModel>>.value(<ExperimentNoteModel>[]);
    }

    return _notesRef(
      cleanLabId,
      cleanNotebookOwnerUid,
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

  Future<String> addProject({
    required NotebookProjectModel project,
    String? notebookOwnerUid,
  }) async {
    final cleanLabId = project.labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(
      notebookOwnerUid ?? project.ownerUid,
    );

    if (cleanLabId.isEmpty || cleanNotebookOwnerUid.isEmpty) {
      throw Exception('No lab selected.');
    }

    _ensureOwnerWriteAccess(cleanNotebookOwnerUid);

    return _runGuarded(() async {
      final docRef = _projectsRef(cleanLabId, cleanNotebookOwnerUid).doc();
      await docRef.set(project.toMap());
      return docRef.id;
    });
  }

  Future<String> addExperiment({
    required NotebookExperimentModel experiment,
    String? notebookOwnerUid,
  }) async {
    final cleanLabId = experiment.labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(
      notebookOwnerUid ?? experiment.ownerUid,
    );
    final cleanProjectId = experiment.projectId.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty) {
      throw Exception('Project or lab context is missing.');
    }

    _ensureOwnerWriteAccess(cleanNotebookOwnerUid);

    return _runGuarded(() async {
      final docRef = _experimentsRef(
        cleanLabId,
        cleanNotebookOwnerUid,
        cleanProjectId,
      ).doc();
      await docRef.set(experiment.toMap());
      return docRef.id;
    });
  }

  Future<void> updateExperiment({
    required NotebookExperimentModel experiment,
    String? notebookOwnerUid,
  }) async {
    final cleanLabId = experiment.labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(
      notebookOwnerUid ?? experiment.ownerUid,
    );
    final cleanProjectId = experiment.projectId.trim();
    final cleanExperimentId = experiment.id.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty) {
      throw Exception('Experiment context is missing.');
    }

    _ensureOwnerWriteAccess(cleanNotebookOwnerUid);

    await _runGuarded(() async {
      await _experimentRef(
        cleanLabId,
        cleanNotebookOwnerUid,
        cleanProjectId,
        cleanExperimentId,
      ).update(experiment.toMap());
    });
  }

  Future<String> addExperimentNote({
    required String labId,
    required String projectId,
    required String experimentId,
    required ExperimentNoteModel note,
    String? notebookOwnerUid,
  }) async {
    final cleanLabId = labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(
      notebookOwnerUid ?? note.ownerUid,
    );
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty) {
      throw Exception('Experiment context is missing.');
    }

    _ensureOwnerWriteAccess(cleanNotebookOwnerUid);

    return _runGuarded(() async {
      final noteRef = _notesRef(
        cleanLabId,
        cleanNotebookOwnerUid,
        cleanProjectId,
        cleanExperimentId,
      ).doc();
      final batch = _firestore.batch();

      batch.set(noteRef, note.toMap());
      batch.update(
        _experimentRef(
          cleanLabId,
          cleanNotebookOwnerUid,
          cleanProjectId,
          cleanExperimentId,
        ),
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
    String? notebookOwnerUid,
  }) async {
    final cleanLabId = labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(notebookOwnerUid);
    final cleanProjectId = projectId.trim();
    final cleanExperimentId = experimentId.trim();
    final cleanStatus = status.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty ||
        cleanExperimentId.isEmpty ||
        cleanStatus.isEmpty) {
      throw Exception('Experiment status could not be updated.');
    }

    _ensureOwnerWriteAccess(cleanNotebookOwnerUid);

    await _runGuarded(() async {
      await _experimentRef(
        cleanLabId,
        cleanNotebookOwnerUid,
        cleanProjectId,
        cleanExperimentId,
      ).update({'status': cleanStatus, 'updatedAt': Timestamp.now()});
    });
  }

  Future<String> getNextDuplicateExperimentCode({
    required String labId,
    required String projectId,
    required String originalCode,
    String? notebookOwnerUid,
  }) async {
    final cleanLabId = labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(notebookOwnerUid);
    final cleanProjectId = projectId.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty) {
      throw Exception('Experiment context is missing.');
    }

    _ensureOwnerWriteAccess(cleanNotebookOwnerUid);

    return _runGuarded(() async {
      final existingCodes = await _existingExperimentCodes(
        labId: cleanLabId,
        notebookOwnerUid: cleanNotebookOwnerUid,
        projectId: cleanProjectId,
      );
      return _nextDuplicateExperimentCode(originalCode, existingCodes);
    });
  }

  Future<String> duplicateExperiment({
    required NotebookExperimentModel sourceExperiment,
    String? notebookOwnerUid,
  }) async {
    final cleanLabId = sourceExperiment.labId.trim();
    final cleanNotebookOwnerUid = resolveNotebookOwnerUid(
      notebookOwnerUid ?? sourceExperiment.ownerUid,
    );
    final cleanProjectId = sourceExperiment.projectId.trim();
    final sourceOwnerUid = sourceExperiment.ownerUid.trim();

    if (cleanLabId.isEmpty ||
        cleanNotebookOwnerUid.isEmpty ||
        cleanProjectId.isEmpty) {
      throw Exception('Experiment context is missing.');
    }

    if (sourceOwnerUid.isNotEmpty && sourceOwnerUid != cleanNotebookOwnerUid) {
      throw const LabDataAccessException(readOnlyMessage);
    }

    _ensureOwnerWriteAccess(cleanNotebookOwnerUid);

    return _runGuarded(() async {
      final experimentsRef = _experimentsRef(
        cleanLabId,
        cleanNotebookOwnerUid,
        cleanProjectId,
      );
      final duplicateCode = await getNextDuplicateExperimentCode(
        labId: cleanLabId,
        projectId: cleanProjectId,
        originalCode: sourceExperiment.experimentCode,
        notebookOwnerUid: cleanNotebookOwnerUid,
      );

      final now = Timestamp.now();
      final duplicatedExperiment = NotebookExperimentModel(
        id: '',
        experimentCode: duplicateCode,
        title: sourceExperiment.title,
        date: now,
        aim: sourceExperiment.aim,
        reactionTitle: sourceExperiment.reactionTitle,
        startingMaterial: '',
        reagents: '',
        catalyst: '',
        solvent: sourceExperiment.solvent,
        temperature: sourceExperiment.temperature,
        startTime: sourceExperiment.startTime,
        endTime: sourceExperiment.endTime,
        time: '',
        atmosphere: sourceExperiment.atmosphere,
        scale: '',
        procedure: sourceExperiment.procedure,
        observations: '',
        workup: sourceExperiment.workup,
        purification: sourceExperiment.purification,
        yieldText: '',
        characterization: sourceExperiment.characterization,
        conclusion: '',
        reactionComponents: sourceExperiment.reactionComponents
            .map((item) => ReactionComponentModel.fromMap(item.toMap()))
            .toList(growable: false),
        editHistory: const <ExperimentEditHistoryModel>[],
        status: notebookExperimentStatuses.first,
        ownerUid: cleanNotebookOwnerUid,
        ownerEmail: sourceExperiment.ownerEmail,
        createdBy: _createdByValue(),
        userEmail: currentUserEmail.isEmpty
            ? sourceExperiment.userEmail
            : currentUserEmail,
        createdAt: now,
        updatedAt: now,
        labId: cleanLabId,
        projectId: cleanProjectId,
      );

      final docRef = experimentsRef.doc();
      await docRef.set(duplicatedExperiment.toMap());
      return docRef.id;
    });
  }
}
