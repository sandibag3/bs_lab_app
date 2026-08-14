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
}
