import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  int _statusRank(EventModel event) {
    if (event.isCompleted) {
      return 2;
    }

    if (event.scheduledAt.isBefore(DateTime.now())) {
      return 1;
    }

    return 0;
  }

  int _compareEvents(EventModel a, EventModel b) {
    final statusComparison = _statusRank(a).compareTo(_statusRank(b));
    if (statusComparison != 0) {
      return statusComparison;
    }

    return a.scheduledAt.compareTo(b.scheduledAt);
  }

  Future<String> addEvent(EventModel event) async {
    final doc = await _firestore.collection('events').add(event.toMap());
    return doc.id;
  }

  Stream<List<EventModel>> getEvents() {
    return _firestore.collection('events').snapshots().map((snapshot) {
      final events = snapshot.docs
          .where((doc) => _matchesCurrentLab(doc.data()))
          .map((doc) => EventModel.fromFirestore(doc))
          .toList();

      events.sort(_compareEvents);
      return events;
    });
  }

  Future<void> markDone({required String docId}) async {
    await _firestore.collection('events').doc(docId).update({
      'isCompleted': true,
      'completedAt': Timestamp.now(),
    });
  }

  Future<void> rescheduleEvent({
    required String docId,
    required DateTime scheduledAt,
  }) async {
    await _firestore.collection('events').doc(docId).update({
      'dateTime': Timestamp.fromDate(scheduledAt),
    });
  }

  Future<void> deleteEvent({required String docId}) async {
    await _firestore.collection('events').doc(docId).delete();
  }
}
