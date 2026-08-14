import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';
import '../models/event_model.dart';
import 'firestore_access_guard.dart';
import 'lab_membership_service.dart';
import 'person_display_resolver.dart';
import 'notification_service.dart';

class EventService {
  static final Set<String> _birthdayCheckKeys = <String>{};

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LabMembershipService _labMembershipService = LabMembershipService();
  final NotificationService _notificationService = NotificationService();

  bool _matchesCurrentLab(Map<String, dynamic> data) {
    final labId = (data['labId'] ?? '').toString().trim();
    return AppState.instance.matchesSelectedLabId(labId);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventSnapshots() {
    final appState = AppState.instance;
    final selectedLabId = appState.selectedLabId.trim();

    if (appState.isDemoLabSelected) {
      return _firestore.collection('events').snapshots();
    }

    return _firestore
        .collection('events')
        .where('labId', isEqualTo: selectedLabId)
        .snapshots();
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

  Future<void> ensureBirthdayCelebrationEventsForActiveLab({
    DateTime? now,
  }) async {
    final appState = AppState.instance;
    final labId = appState.selectedLabId.trim();
    if (labId.isEmpty ||
        appState.isDemoLabSelected ||
        appState.isLocalFallbackLabSelected ||
        !FirestoreAccessGuard.shouldQueryLabScopedData(appState: appState)) {
      return;
    }

    final today = _dateOnly(now ?? DateTime.now());
    final checkKey = '$labId|${today.year}-${today.month}-${today.day}';
    if (!_birthdayCheckKeys.add(checkKey)) {
      return;
    }

    try {
      final eligibleMemberships =
          (await _labMembershipService.getMembershipsForLab(
            labId: labId,
          )).where((membership) => membership.grantsActiveAccess).toList();

      for (final membership in eligibleMemberships) {
        final userId = membership.userId.trim();
        final birthDay = membership.birthDay;
        final birthMonth = membership.birthMonth;
        if (userId.isEmpty || birthDay == null || birthMonth == null) {
          continue;
        }

        final birthday = _nextBirthdayFor(
          birthMonth: birthMonth,
          birthDay: birthDay,
          today: today,
        );
        if (birthday == null || birthday.difference(today).inDays != 2) {
          continue;
        }

        final resolvedName = PersonDisplayResolver.resolvePersonDisplayName(
          membership: membership,
          email: membership.userEmail,
          uid: userId,
          fallbackLabel: 'a lab member',
        );
        final displayName =
            PersonDisplayResolver.hasUsableDisplayName(resolvedName)
            ? resolvedName.trim()
            : 'a lab member';

        await _createBirthdayCelebrationIfMissing(
          labId: labId,
          userId: userId,
          displayName: displayName,
          birthday: birthday,
          recipientUserIds: eligibleMemberships.map(
            (membership) => membership.userId,
          ),
        );
      }
    } catch (_) {
      // Birthday generation is opportunistic and must never block Home.
    }
  }

  Stream<List<EventModel>> getEvents() {
    return FirestoreAccessGuard.guardLabStream<List<EventModel>>(
      source: _eventSnapshots(),
      emptyValue: <EventModel>[],
      onData: (snapshot) {
        final docs = AppState.instance.isDemoLabSelected
            ? snapshot.docs.where((doc) => _matchesCurrentLab(doc.data()))
            : snapshot.docs;

        final events = docs
            .map((doc) => EventModel.fromFirestore(doc))
            .toList();
        events.sort(_compareEvents);
        return events;
      },
    );
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

  Future<bool> _createBirthdayCelebrationIfMissing({
    required String labId,
    required String userId,
    required String displayName,
    required DateTime birthday,
    required Iterable<String> recipientUserIds,
  }) async {
    final eventId = _birthdayEventId(
      labId: labId,
      userId: userId,
      birthdayYear: birthday.year,
    );
    final eventRef = _firestore.collection('events').doc(eventId);
    final birthdayLabel = _formatBirthdayDayMonth(birthday);

    final created = await _firestore.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(eventRef);
      if (existing.exists) {
        return false;
      }

      transaction.set(eventRef, {
        'labId': labId,
        'title':
            "Get ready to celebrate $displayName's birthday on $birthdayLabel",
        'eventType': 'Celebration',
        'venue': '',
        'description': '',
        'dateTime': Timestamp.fromDate(
          DateTime(birthday.year, birthday.month, birthday.day, 9),
        ),
        'createdBy': 'Labmate',
        'createdById': 'labmate',
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
        'birthdayUserId': userId,
        'birthdayYear': birthday.year,
      });
      return true;
    });

    if (!created) {
      return false;
    }

    try {
      await _notificationService.notifyBirthdayEvent(
        targetUserIds: recipientUserIds,
        labId: labId,
        eventId: eventId,
        birthdayUserId: userId,
        birthdayYear: birthday.year,
        birthdayName: displayName,
        birthdayLabel: birthdayLabel,
        actorUid: AppState.instance.authenticatedUserId,
      );
    } catch (_) {
      // Notification failures must not block birthday event creation.
    }
    return true;
  }

  String _birthdayEventId({
    required String labId,
    required String userId,
    required int birthdayYear,
  }) {
    return 'birthday_${_safeEventIdPart(labId)}_${_safeEventIdPart(userId)}_$birthdayYear';
  }

  String _safeEventIdPart(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _nextBirthdayFor({
    required int birthMonth,
    required int birthDay,
    required DateTime today,
  }) {
    var birthday = _birthdayDateForYear(
      year: today.year,
      month: birthMonth,
      day: birthDay,
    );
    if (birthday == null) {
      return null;
    }

    if (birthday.isBefore(today)) {
      birthday = _birthdayDateForYear(
        year: today.year + 1,
        month: birthMonth,
        day: birthDay,
      );
    }
    return birthday;
  }

  DateTime? _birthdayDateForYear({
    required int year,
    required int month,
    required int day,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    if (month == 2 && day == 29 && !_isLeapYear(year)) {
      return DateTime(year, 2, 28);
    }

    final parsed = DateTime(year, month, day);
    if (parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
  }

  String _formatBirthdayDayMonth(DateTime value) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${value.day} ${monthNames[value.month - 1]}';
  }
}
