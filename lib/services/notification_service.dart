import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId.trim())
        .collection('notifications');
  }

  Stream<List<NotificationModel>> streamNotifications({
    required String userId,
    int limit = 100,
  }) {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return Stream.value(const <NotificationModel>[]);
    }

    final safeLimit = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
    return _notificationsRef(cleanUserId)
        .orderBy('createdAt', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map(NotificationModel.fromFirestore)
              .toList();
          notifications.sort(_compareNewestFirst);
          return notifications;
        });
  }

  Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    final cleanUserId = userId.trim();
    final cleanNotificationId = notificationId.trim();
    if (cleanUserId.isEmpty || cleanNotificationId.isEmpty) {
      return;
    }

    await _notificationsRef(cleanUserId).doc(cleanNotificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead({required String userId}) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      return;
    }

    final snapshot = await _notificationsRef(
      cleanUserId,
    ).where('isRead', isEqualTo: false).limit(100).get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> notifyJoinRequest({
    required String targetPiUid,
    required String labId,
    required String labName,
    required String requestId,
    required String requesterName,
    required String requesterUid,
  }) async {
    final cleanTargetUid = targetPiUid.trim();
    final cleanLabId = labId.trim();
    final cleanRequestId = requestId.trim();
    final cleanRequesterUid = requesterUid.trim();
    if (cleanTargetUid.isEmpty ||
        cleanLabId.isEmpty ||
        cleanRequestId.isEmpty ||
        cleanRequesterUid.isEmpty) {
      return;
    }

    final cleanLabName = labName.trim().isEmpty ? cleanLabId : labName.trim();
    final cleanRequesterName = requesterName.trim().isEmpty
        ? 'A user'
        : requesterName.trim();

    await _createIfMissing(
      targetUserId: cleanTargetUid,
      notificationId: _joinNotificationId('join_request', cleanRequestId),
      type: NotificationModel.typeJoinRequest,
      title: 'New lab join request',
      message: '$cleanRequesterName requested to join $cleanLabName.',
      labId: cleanLabId,
      entityId: cleanRequestId,
      entityType: 'labJoinRequest',
      route: 'lab_members',
      actionKey: 'review_join_request',
      createdByUid: cleanRequesterUid,
      createdByName: cleanRequesterName,
    );
  }

  Future<void> notifyJoinDecision({
    required String targetUserId,
    required String labId,
    required String labName,
    required String requestId,
    required bool approved,
    required String reviewerUid,
    required String reviewerName,
  }) async {
    final cleanTargetUid = targetUserId.trim();
    final cleanLabId = labId.trim();
    final cleanRequestId = requestId.trim();
    final cleanReviewerUid = reviewerUid.trim();
    if (cleanTargetUid.isEmpty ||
        cleanLabId.isEmpty ||
        cleanRequestId.isEmpty ||
        cleanReviewerUid.isEmpty) {
      return;
    }

    final type = approved
        ? NotificationModel.typeJoinApproved
        : NotificationModel.typeJoinRejected;
    final cleanLabName = labName.trim().isEmpty ? cleanLabId : labName.trim();
    final cleanReviewerName = reviewerName.trim().isEmpty
        ? 'The PI'
        : reviewerName.trim();

    await _createIfMissing(
      targetUserId: cleanTargetUid,
      notificationId: _joinNotificationId(type, cleanRequestId),
      type: type,
      title: approved ? 'Lab access approved' : 'Lab join request rejected',
      message: approved
          ? 'Your request to join $cleanLabName was approved.'
          : 'Your request to join $cleanLabName was rejected.',
      labId: cleanLabId,
      entityId: cleanRequestId,
      entityType: 'labJoinRequest',
      route: '',
      actionKey: approved ? 'join_approved' : 'join_rejected',
      createdByUid: cleanReviewerUid,
      createdByName: cleanReviewerName,
    );
  }

  Future<void> notifyRequirementDecision({
    required String targetUserId,
    required String labId,
    required String requirementId,
    required String itemName,
    required bool approved,
    required String actorUid,
    required String actorName,
  }) async {
    final cleanTargetUid = targetUserId.trim();
    final cleanLabId = labId.trim();
    final cleanRequirementId = requirementId.trim();
    final cleanActorUid = actorUid.trim();
    if (cleanTargetUid.isEmpty ||
        cleanLabId.isEmpty ||
        cleanRequirementId.isEmpty ||
        cleanActorUid.isEmpty ||
        cleanTargetUid == cleanActorUid) {
      return;
    }

    final status = approved ? 'approved' : 'rejected';
    final type = approved
        ? NotificationModel.typeRequirementApproved
        : NotificationModel.typeRequirementRejected;
    final cleanItemName = itemName.trim().isEmpty ? 'item' : itemName.trim();
    final cleanActorName = actorName.trim().isEmpty
        ? cleanActorUid
        : actorName.trim();

    await _createIfMissing(
      targetUserId: cleanTargetUid,
      notificationId: _workflowNotificationId(
        'requirement_$status',
        cleanRequirementId,
      ),
      type: type,
      title: approved ? 'Requirement approved' : 'Requirement rejected',
      message: 'Your requirement for $cleanItemName was $status.',
      labId: cleanLabId,
      entityId: cleanRequirementId,
      entityType: 'requirement',
      route: 'cart',
      actionKey: 'requirement_$status',
      createdByUid: cleanActorUid,
      createdByName: cleanActorName,
    );
  }

  Future<void> notifyOrderDelivered({
    required String targetUserId,
    required String labId,
    required String orderId,
    required String itemName,
    required String actorUid,
    required String actorName,
  }) async {
    final cleanTargetUid = targetUserId.trim();
    final cleanLabId = labId.trim();
    final cleanOrderId = orderId.trim();
    final cleanActorUid = actorUid.trim();
    if (cleanTargetUid.isEmpty ||
        cleanLabId.isEmpty ||
        cleanOrderId.isEmpty ||
        cleanActorUid.isEmpty ||
        cleanTargetUid == cleanActorUid) {
      return;
    }

    final cleanItemName = itemName.trim().isEmpty ? 'item' : itemName.trim();
    final cleanActorName = actorName.trim().isEmpty
        ? cleanActorUid
        : actorName.trim();

    await _createIfMissing(
      targetUserId: cleanTargetUid,
      notificationId: _workflowNotificationId('order_delivered', cleanOrderId),
      type: NotificationModel.typeOrderDelivered,
      title: 'Order delivered',
      message: 'Your ordered item $cleanItemName has been marked as delivered.',
      labId: cleanLabId,
      entityId: cleanOrderId,
      entityType: 'order',
      route: 'orders',
      actionKey: 'order_delivered',
      createdByUid: cleanActorUid,
      createdByName: cleanActorName,
    );
  }

  Future<void> notifyBirthdayEvent({
    required Iterable<String> targetUserIds,
    required String labId,
    required String eventId,
    required String birthdayUserId,
    required int birthdayYear,
    required String birthdayName,
    required String birthdayLabel,
    required String actorUid,
  }) async {
    final cleanLabId = labId.trim();
    final cleanEventId = eventId.trim();
    final cleanBirthdayUserId = birthdayUserId.trim();
    final cleanActorUid = actorUid.trim();
    final recipients = targetUserIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet()
        .toList();
    if (cleanLabId.isEmpty ||
        cleanEventId.isEmpty ||
        cleanBirthdayUserId.isEmpty ||
        cleanActorUid.isEmpty ||
        recipients.isEmpty) {
      return;
    }

    final cleanBirthdayName = birthdayName.trim().isEmpty
        ? 'a lab member'
        : birthdayName.trim();
    final cleanBirthdayLabel = birthdayLabel.trim().isEmpty
        ? 'their birthday'
        : birthdayLabel.trim();
    final references = recipients.map((recipientId) {
      final notificationId = _birthdayNotificationId(
        labId: cleanLabId,
        birthdayUserId: cleanBirthdayUserId,
        birthdayYear: birthdayYear,
        recipientUserId: recipientId,
      );
      return _notificationsRef(recipientId).doc(notificationId);
    }).toList();

    final existingSnapshots = await Future.wait(
      references.map((reference) => reference.get()),
    );
    final missing = <DocumentReference<Map<String, dynamic>>>[];
    for (var index = 0; index < references.length; index++) {
      if (!existingSnapshots[index].exists) {
        missing.add(references[index]);
      }
    }

    for (var start = 0; start < missing.length; start += 400) {
      final end = (start + 400) > missing.length ? missing.length : start + 400;
      final batch = _firestore.batch();
      for (final reference in missing.sublist(start, end)) {
        batch.set(reference, {
          'type': NotificationModel.typeBirthday,
          'title': 'Upcoming birthday 🎉',
          'message':
              'Get ready to celebrate $cleanBirthdayName\'s birthday on $cleanBirthdayLabel.',
          'labId': cleanLabId,
          'createdAt': FieldValue.serverTimestamp(),
          'readAt': null,
          'isRead': false,
          'entityId': cleanEventId,
          'entityType': 'event',
          'route': 'events',
          'actionKey': 'birthday',
          'createdByUid': cleanActorUid,
          'createdByName': 'Labmate',
        });
      }
      await batch.commit();
    }
  }

  Future<void> _createIfMissing({
    required String targetUserId,
    required String notificationId,
    required String type,
    required String title,
    required String message,
    required String labId,
    required String entityId,
    required String entityType,
    required String route,
    required String actionKey,
    required String createdByUid,
    required String createdByName,
  }) async {
    final notificationRef = _notificationsRef(targetUserId).doc(notificationId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(notificationRef);
      if (existing.exists) {
        return;
      }

      transaction.set(notificationRef, {
        'type': type,
        'title': title,
        'message': message,
        'labId': labId,
        'createdAt': FieldValue.serverTimestamp(),
        'readAt': null,
        'isRead': false,
        'entityId': entityId,
        'entityType': entityType,
        'route': route,
        'actionKey': actionKey,
        'createdByUid': createdByUid,
        'createdByName': createdByName,
      });
    });
  }

  int _compareNewestFirst(NotificationModel a, NotificationModel b) {
    final left = a.createdAt;
    final right = b.createdAt;
    if (left == null && right == null) {
      return b.id.compareTo(a.id);
    }
    if (left == null) return 1;
    if (right == null) return -1;
    final createdCompare = right.compareTo(left);
    return createdCompare == 0 ? b.id.compareTo(a.id) : createdCompare;
  }

  String _joinNotificationId(String type, String requestId) {
    return '${type}_${requestId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
  }

  String _workflowNotificationId(String type, String entityId) {
    return '${type}_${entityId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
  }

  String _birthdayNotificationId({
    required String labId,
    required String birthdayUserId,
    required int birthdayYear,
    required String recipientUserId,
  }) {
    return 'birthday_${_safeIdPart(labId)}_${_safeIdPart(birthdayUserId)}_'
        '${birthdayYear}_${_safeIdPart(recipientUserId)}';
  }

  String _safeIdPart(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}
