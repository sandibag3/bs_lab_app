import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String labId;
  final String type;
  final String message;
  final Timestamp createdAt;
  final String createdBy;
  final String actorName;
  final String relatedId;

  const ActivityModel({
    required this.id,
    required this.labId,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.createdBy,
    required this.actorName,
    required this.relatedId,
  });

  factory ActivityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ActivityModel(
      id: doc.id,
      labId: data['labId'] ?? '',
      type: data['type'] ?? '',
      message: data['message'] ?? data['title'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
      actorName: data['actorName'] ?? '',
      relatedId: data['relatedId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'labId': labId,
      'type': type,
      'message': message,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'actorName': actorName,
      'relatedId': relatedId,
    };
  }
}
