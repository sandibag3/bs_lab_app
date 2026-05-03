import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String labId;
  final String title;
  final String eventType;
  final String venue;
  final String description;
  final Timestamp dateTime;
  final String createdBy;
  final String createdById;
  final bool isCompleted;
  final Timestamp createdAt;
  final Timestamp? completedAt;

  EventModel({
    required this.id,
    required this.labId,
    required this.title,
    required this.eventType,
    required this.venue,
    required this.description,
    required this.dateTime,
    required this.createdBy,
    required this.createdById,
    required this.isCompleted,
    required this.createdAt,
    required this.completedAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return EventModel(
      id: doc.id,
      labId: (data['labId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      eventType: (data['eventType'] ?? '').toString(),
      venue: (data['venue'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      dateTime: data['dateTime'] is Timestamp
          ? data['dateTime'] as Timestamp
          : Timestamp.now(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdById: (data['createdById'] ?? '').toString(),
      isCompleted: data['isCompleted'] == true,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      completedAt: data['completedAt'] is Timestamp
          ? data['completedAt'] as Timestamp
          : null,
    );
  }

  DateTime get scheduledAt => dateTime.toDate();
  String get normalizedTitle => title.trim().isEmpty ? 'Untitled Event' : title.trim();
  String get normalizedEventType =>
      eventType.trim().isEmpty ? 'General' : eventType.trim();
  String get normalizedVenue => venue.trim();
  bool get hasVenue => normalizedVenue.isNotEmpty;

  bool get isUpcoming {
    return !isCompleted && !scheduledAt.isBefore(DateTime.now());
  }

  Map<String, dynamic> toMap() {
    return {
      'labId': labId,
      'title': title,
      'eventType': eventType,
      'venue': venue,
      'description': description,
      'dateTime': dateTime,
      'createdBy': createdBy,
      'createdById': createdById,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'completedAt': completedAt,
    };
  }
}
