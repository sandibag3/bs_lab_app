import 'package:cloud_firestore/cloud_firestore.dart';

class ExperimentEditHistoryModel {
  final Timestamp editedAt;
  final String editedByUid;
  final String editedByEmail;
  final String summary;

  const ExperimentEditHistoryModel({
    required this.editedAt,
    required this.editedByUid,
    required this.editedByEmail,
    required this.summary,
  });

  factory ExperimentEditHistoryModel.fromMap(Map<String, dynamic> data) {
    return ExperimentEditHistoryModel(
      editedAt: data['editedAt'] is Timestamp
          ? data['editedAt'] as Timestamp
          : Timestamp.now(),
      editedByUid: (data['editedByUid'] ?? '').toString(),
      editedByEmail: (data['editedByEmail'] ?? '').toString(),
      summary: (data['summary'] ?? '').toString(),
    );
  }

  String get editorLabel {
    final cleanEmail = editedByEmail.trim();
    if (cleanEmail.isNotEmpty) {
      return cleanEmail;
    }

    final cleanUid = editedByUid.trim();
    if (cleanUid.isNotEmpty) {
      return cleanUid;
    }

    return 'Unknown user';
  }

  Map<String, dynamic> toMap() {
    return {
      'editedAt': editedAt,
      'editedByUid': editedByUid,
      'editedByEmail': editedByEmail,
      'summary': summary,
    };
  }
}
