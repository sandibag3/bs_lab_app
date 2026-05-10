import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';

class LabDataAccessException implements Exception {
  final String message;

  const LabDataAccessException([this.message = FirestoreAccessGuard.userMessage]);

  @override
  String toString() => message;
}

class FirestoreAccessGuard {
  static const String userMessage =
      "You don't have access to this lab data yet. Please create or join a lab.";

  static bool isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      final code = error.code.trim().toLowerCase();
      if (code == 'permission-denied') {
        return true;
      }

      final message = (error.message ?? '').toLowerCase();
      return message.contains('permission denied') ||
          message.contains('permission_denied');
    }

    final text = error.toString().toLowerCase();
    return text.contains('permission denied') ||
        text.contains('permission_denied') ||
        text.contains('permission-denied');
  }

  static bool shouldQueryLabScopedData({AppState? appState}) {
    final state = appState ?? AppState.instance;
    final selectedLabId = state.selectedLabId.trim();

    if (selectedLabId.isEmpty) {
      return false;
    }

    if (state.isLocalFallbackLabSelected) {
      return false;
    }

    return true;
  }

  static String messageFor(
    Object? error, {
    String fallback = userMessage,
  }) {
    if (error == null) {
      return fallback;
    }

    if (error is LabDataAccessException) {
      return error.message;
    }

    if (isPermissionDenied(error)) {
      return userMessage;
    }

    final clean = error.toString().replaceFirst('Exception: ', '').trim();
    return clean.isEmpty ? fallback : clean;
  }

  static Stream<T> guardLabStream<T>({
    required Stream<QuerySnapshot<Map<String, dynamic>>> source,
    required T emptyValue,
    required T Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    AppState? appState,
  }) {
    if (!shouldQueryLabScopedData(appState: appState)) {
      return Stream<T>.value(emptyValue);
    }

    return source.transform(
      StreamTransformer<QuerySnapshot<Map<String, dynamic>>, T>.fromHandlers(
        handleData: (snapshot, sink) {
          sink.add(onData(snapshot));
        },
        handleError: (error, stackTrace, sink) {
          if (isPermissionDenied(error)) {
            sink.addError(const LabDataAccessException(), stackTrace);
            return;
          }

          sink.addError(error, stackTrace);
        },
      ),
    );
  }
}
