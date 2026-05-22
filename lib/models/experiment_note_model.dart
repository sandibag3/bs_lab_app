import 'package:cloud_firestore/cloud_firestore.dart';

class ExperimentNoteModel {
  final String id;
  final String note;
  final String ownerUid;
  final String ownerEmail;
  final String createdBy;
  final String userEmail;
  final Timestamp createdAt;

  const ExperimentNoteModel({
    required this.id,
    required this.note,
    required this.ownerUid,
    required this.ownerEmail,
    required this.createdBy,
    required this.userEmail,
    required this.createdAt,
  });

  factory ExperimentNoteModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ExperimentNoteModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory ExperimentNoteModel.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return ExperimentNoteModel(
      id: id,
      note: (data['note'] ?? '').toString(),
      ownerUid: (data['ownerUid'] ?? '').toString(),
      ownerEmail: (data['ownerEmail'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  String get creatorLabel {
    final cleanUserEmail = userEmail.trim();
    if (cleanUserEmail.isNotEmpty) {
      return cleanUserEmail;
    }

    final cleanCreatedBy = createdBy.trim();
    return cleanCreatedBy.isEmpty ? 'Unknown user' : cleanCreatedBy;
  }

  String get ownerLabel {
    final cleanOwnerEmail = ownerEmail.trim();
    if (cleanOwnerEmail.isNotEmpty) {
      return cleanOwnerEmail;
    }

    final cleanOwnerUid = ownerUid.trim();
    if (cleanOwnerUid.isNotEmpty) {
      return cleanOwnerUid;
    }

    return creatorLabel;
  }

  Map<String, dynamic> toMap() {
    return {
      'note': note,
      'ownerUid': ownerUid,
      'ownerEmail': ownerEmail,
      'createdBy': createdBy,
      'userEmail': userEmail,
      'createdAt': createdAt,
    };
  }
}
