import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';

class ActivityService {
  final CollectionReference<Map<String, dynamic>> _activitiesRef =
      FirebaseFirestore.instance.collection('activities');

  Future<void> addActivity({
    required String labId,
    required String type,
    required String message,
    required String actorName,
    String createdBy = '',
    String relatedId = '',
  }) async {
    final cleanLabId = labId.trim();
    final cleanType = type.trim();
    final cleanMessage = message.trim();

    if (cleanLabId.isEmpty || cleanType.isEmpty || cleanMessage.isEmpty) {
      return;
    }

    final activity = ActivityModel(
      id: '',
      labId: cleanLabId,
      type: cleanType,
      message: cleanMessage,
      createdAt: Timestamp.now(),
      createdBy: createdBy.trim(),
      actorName: actorName.trim(),
      relatedId: relatedId.trim(),
    );

    await _activitiesRef.add(activity.toMap());
  }

  Stream<List<ActivityModel>> getActivitiesForLab(String labId) {
    final cleanLabId = labId.trim();
    if (cleanLabId.isEmpty) {
      return Stream.value([]);
    }

    return _activitiesRef.where('labId', isEqualTo: cleanLabId).snapshots().map(
      (snapshot) {
        final activities = snapshot.docs
            .map(ActivityModel.fromFirestore)
            .toList();
        activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return activities.take(50).toList();
      },
    );
  }
}
