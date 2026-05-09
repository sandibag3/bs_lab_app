import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_record_model.dart';
import 'firestore_access_guard.dart';

class AttendanceActionResult {
  final bool isSuccess;
  final String message;
  final AttendanceRecordModel? record;

  const AttendanceActionResult._({
    required this.isSuccess,
    required this.message,
    required this.record,
  });

  const AttendanceActionResult.success({
    String message = '',
    AttendanceRecordModel? record,
  }) : this._(
          isSuccess: true,
          message: message,
          record: record,
        );

  const AttendanceActionResult.failure({
    required String message,
    AttendanceRecordModel? record,
  }) : this._(
          isSuccess: false,
          message: message,
          record: record,
        );
}

class _AttendanceActionException implements Exception {
  final String message;

  const _AttendanceActionException(this.message);

  @override
  String toString() => message;
}

class AttendanceService {
  static const String checkInStatus = 'checkedIn';
  static const String checkOutStatus = 'checkedOut';
  static const String checkInMethodWifi = 'wifi';
  static const String checkInMethodManual = 'manual';
  static const String checkOutMethodManual = 'manual';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _attendanceRecordsRef(String labId) {
    return _firestore
        .collection('labs')
        .doc(labId)
        .collection('attendanceRecords');
  }

  String _dateKeyFor(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _todayDateKey() => _dateKeyFor(DateTime.now());

  String _recordIdForToday({required String userId}) {
    return '${_todayDateKey()}__${userId.trim()}';
  }

  Future<T> _runGuarded<T>(
    Future<T> Function() action, {
    required String debugLabel,
  }) async {
    try {
      return await action();
    } on FirebaseException catch (error) {
      debugPrint('$debugLabel failed: $error');
      if (FirestoreAccessGuard.isPermissionDenied(error)) {
        throw const LabDataAccessException();
      }
      rethrow;
    } catch (error) {
      debugPrint('$debugLabel failed: $error');
      rethrow;
    }
  }

  Stream<List<AttendanceRecordModel>> _guardedRecordsStream({
    required String labId,
    required Stream<QuerySnapshot<Map<String, dynamic>>> source,
    required List<AttendanceRecordModel> Function(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) onData,
  }) {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      debugPrint('Attendance stream skipped: missing labId.');
      return Stream<List<AttendanceRecordModel>>.value(
        <AttendanceRecordModel>[],
      );
    }

    return source.transform(
      StreamTransformer<QuerySnapshot<Map<String, dynamic>>,
          List<AttendanceRecordModel>>.fromHandlers(
        handleData: (snapshot, sink) {
          sink.add(onData(snapshot));
        },
        handleError: (error, stackTrace, sink) {
          debugPrint('Attendance stream failed for lab $cleanLabId: $error');
          if (FirestoreAccessGuard.isPermissionDenied(error)) {
            sink.addError(const LabDataAccessException(), stackTrace);
            return;
          }
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  List<AttendanceRecordModel> _sortTodayRecords(
    Iterable<AttendanceRecordModel> records,
  ) {
    final sorted = records.toList();
    sorted.sort((a, b) {
      final aTime = a.checkInAt ?? a.createdAt;
      final bTime = b.checkInAt ?? b.createdAt;
      return aTime.compareTo(bTime);
    });
    return sorted;
  }

  List<AttendanceRecordModel> _sortHistoryRecords(
    Iterable<AttendanceRecordModel> records,
  ) {
    final sorted = records.toList();
    sorted.sort((a, b) {
      final dateComparison = b.dateKey.compareTo(a.dateKey);
      if (dateComparison != 0) {
        return dateComparison;
      }
      final aTime = a.checkInAt ?? a.createdAt;
      final bTime = b.checkInAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  Future<AttendanceRecordModel?> getTodayRecord({
    required String labId,
    required String userId,
  }) async {
    final cleanLabId = labId.trim();
    final cleanUserId = userId.trim();
    if (cleanLabId.isEmpty || cleanUserId.isEmpty) {
      debugPrint(
        'Attendance getTodayRecord skipped: labId or userId missing.',
      );
      return null;
    }

    return _runGuarded(
      () async {
        final doc = await _attendanceRecordsRef(cleanLabId)
            .doc(_recordIdForToday(userId: cleanUserId))
            .get();

        if (!doc.exists) {
          return null;
        }

        return AttendanceRecordModel.fromFirestore(doc);
      },
      debugLabel:
          'Attendance getTodayRecord for $cleanLabId / $cleanUserId',
    );
  }

  Future<AttendanceActionResult> checkIn({
    required String labId,
    required String userId,
    required String userName,
    required String userEmail,
    required String wifiSsid,
  }) async {
    final cleanLabId = labId.trim();
    final cleanUserId = userId.trim();
    final cleanUserName = userName.trim();
    final cleanUserEmail = userEmail.trim();
    final cleanWifiSsid = wifiSsid.trim();

    if (cleanLabId.isEmpty || cleanUserId.isEmpty) {
      return const AttendanceActionResult.failure(
        message: 'Lab or user information is missing.',
      );
    }

    try {
      await _runGuarded(
        () async {
          final docRef = _attendanceRecordsRef(cleanLabId).doc(
            _recordIdForToday(userId: cleanUserId),
          );

          await _firestore.runTransaction((transaction) async {
            final existing = await transaction.get(docRef);
            if (existing.exists) {
              throw const _AttendanceActionException(
                'You have already checked in today.',
              );
            }

            transaction.set(docRef, {
              'labId': cleanLabId,
              'userId': cleanUserId,
              'userName': cleanUserName,
              'userEmail': cleanUserEmail,
              'dateKey': _todayDateKey(),
              'checkInAt': FieldValue.serverTimestamp(),
              'checkOutAt': null,
              'checkInMethod': cleanWifiSsid.isEmpty
                  ? checkInMethodManual
                  : checkInMethodWifi,
              'checkOutMethod': '',
              'wifiSsid': cleanWifiSsid,
              'status': checkInStatus,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
        },
        debugLabel: 'Attendance checkIn for $cleanLabId / $cleanUserId',
      );
    } on _AttendanceActionException catch (error) {
      debugPrint(
        'Attendance checkIn prevented for $cleanLabId / $cleanUserId: $error',
      );
      return AttendanceActionResult.failure(message: error.message);
    }

    final record = await getTodayRecord(labId: cleanLabId, userId: cleanUserId);
    return AttendanceActionResult.success(
      message: 'Checked in successfully.',
      record: record,
    );
  }

  Future<AttendanceActionResult> checkOut({
    required String labId,
    required String userId,
  }) async {
    final cleanLabId = labId.trim();
    final cleanUserId = userId.trim();

    if (cleanLabId.isEmpty || cleanUserId.isEmpty) {
      return const AttendanceActionResult.failure(
        message: 'Lab or user information is missing.',
      );
    }

    try {
      await _runGuarded(
        () async {
          final docRef = _attendanceRecordsRef(cleanLabId).doc(
            _recordIdForToday(userId: cleanUserId),
          );

          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(docRef);
            if (!snapshot.exists) {
              throw const _AttendanceActionException(
                'No check-in found for today.',
              );
            }

            final record = AttendanceRecordModel.fromMap(
              snapshot.data() ?? <String, dynamic>{},
              id: snapshot.id,
            );
            if (record.isCheckedOut) {
              throw const _AttendanceActionException(
                'You have already checked out today.',
              );
            }

            transaction.update(docRef, {
              'checkOutAt': FieldValue.serverTimestamp(),
              'checkOutMethod': checkOutMethodManual,
              'status': checkOutStatus,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
        },
        debugLabel: 'Attendance checkOut for $cleanLabId / $cleanUserId',
      );
    } on _AttendanceActionException catch (error) {
      debugPrint(
        'Attendance checkOut prevented for $cleanLabId / $cleanUserId: $error',
      );
      return AttendanceActionResult.failure(message: error.message);
    }

    final record = await getTodayRecord(labId: cleanLabId, userId: cleanUserId);
    return AttendanceActionResult.success(
      message: 'Checked out successfully.',
      record: record,
    );
  }

  Stream<List<AttendanceRecordModel>> getTodayAttendanceForLab({
    required String labId,
  }) {
    final cleanLabId = labId.trim();
    final todayKey = _todayDateKey();

    return _guardedRecordsStream(
      labId: cleanLabId,
      source: _attendanceRecordsRef(cleanLabId)
          .where('dateKey', isEqualTo: todayKey)
          .snapshots(),
      onData: (snapshot) {
        final records = snapshot.docs
            .map(AttendanceRecordModel.fromFirestore)
            .toList();
        return _sortTodayRecords(records);
      },
    );
  }

  Stream<List<AttendanceRecordModel>> getLabAttendanceHistory({
    required String labId,
  }) {
    final cleanLabId = labId.trim();

    return _guardedRecordsStream(
      labId: cleanLabId,
      source: _attendanceRecordsRef(cleanLabId).snapshots(),
      onData: (snapshot) {
        final records = snapshot.docs
            .map(AttendanceRecordModel.fromFirestore)
            .toList();
        return _sortHistoryRecords(records);
      },
    );
  }
}
