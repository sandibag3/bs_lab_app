import 'package:cloud_firestore/cloud_firestore.dart';

class NotebookProjectModel {
  final String id;
  final String title;
  final String description;
  final String ownerUid;
  final String ownerEmail;
  final String createdBy;
  final String userEmail;
  final Timestamp createdAt;
  final String labId;

  const NotebookProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerUid,
    required this.ownerEmail,
    required this.createdBy,
    required this.userEmail,
    required this.createdAt,
    required this.labId,
  });

  factory NotebookProjectModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return NotebookProjectModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory NotebookProjectModel.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return NotebookProjectModel(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      ownerUid: (data['ownerUid'] ?? '').toString(),
      ownerEmail: (data['ownerEmail'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      labId: (data['labId'] ?? '').toString(),
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
      'title': title,
      'description': description,
      'ownerUid': ownerUid,
      'ownerEmail': ownerEmail,
      'createdBy': createdBy,
      'userEmail': userEmail,
      'createdAt': createdAt,
      'labId': labId,
    };
  }
}
