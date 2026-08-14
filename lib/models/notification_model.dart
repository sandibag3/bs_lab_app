import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  static const String typeJoinRequest = 'join_request';
  static const String typeJoinApproved = 'join_approved';
  static const String typeJoinRejected = 'join_rejected';
  static const String typeRequirementSubmitted = 'requirement_submitted';
  static const String typeRequirementApproved = 'requirement_approved';
  static const String typeRequirementRejected = 'requirement_rejected';
  static const String typeOrderDelivered = 'order_delivered';
  static const String typeBirthday = 'birthday';
  static const String typeGeneral = 'general';

  final String id;
  final String type;
  final String title;
  final String message;
  final String labId;
  final DateTime? createdAt;
  final DateTime? readAt;
  final bool isRead;
  final String entityId;
  final String entityType;
  final String route;
  final String actionKey;
  final String createdByUid;
  final String createdByName;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.labId,
    required this.createdAt,
    required this.readAt,
    required this.isRead,
    required this.entityId,
    required this.entityType,
    required this.route,
    required this.actionKey,
    required this.createdByUid,
    required this.createdByName,
  });

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final readAt = _dateTimeFromValue(data['readAt']);

    return NotificationModel(
      id: doc.id,
      type: _stringValue(data['type']),
      title: _stringValue(data['title']),
      message: _stringValue(data['message']),
      labId: _stringValue(data['labId']),
      createdAt: _dateTimeFromValue(data['createdAt']),
      readAt: readAt,
      isRead: data['isRead'] == true || readAt != null,
      entityId: _stringValue(data['entityId']),
      entityType: _stringValue(data['entityType']),
      route: _stringValue(data['route']),
      actionKey: _stringValue(data['actionKey']),
      createdByUid: _stringValue(data['createdByUid']),
      createdByName: _stringValue(data['createdByName']),
    );
  }

  bool get isUnread => !isRead;

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'title': title,
      'message': message,
      'labId': labId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
      'isRead': isRead,
      'entityId': entityId,
      'entityType': entityType,
      'route': route,
      'actionKey': actionKey,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
    };
  }

  static String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
