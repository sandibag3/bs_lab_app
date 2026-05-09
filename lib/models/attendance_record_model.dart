import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecordModel {
  static const List<String> allowedStatuses = [
    'checkedIn',
    'checkedOut',
  ];

  final String id;
  final String labId;
  final String userId;
  final String userName;
  final String userEmail;
  final String dateKey;
  final Timestamp? checkInAt;
  final Timestamp? checkOutAt;
  final String checkInMethod;
  final String checkOutMethod;
  final String wifiSsid;
  final String status;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const AttendanceRecordModel({
    required this.id,
    required this.labId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.dateKey,
    required this.checkInAt,
    required this.checkOutAt,
    required this.checkInMethod,
    required this.checkOutMethod,
    required this.wifiSsid,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceRecordModel.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    return AttendanceRecordModel(
      id: id.trim(),
      labId: (data['labId'] ?? '').toString().trim(),
      userId: (data['userId'] ?? '').toString().trim(),
      userName: (data['userName'] ?? '').toString().trim(),
      userEmail: (data['userEmail'] ?? '').toString().trim(),
      dateKey: (data['dateKey'] ?? '').toString().trim(),
      checkInAt: data['checkInAt'] is Timestamp
          ? data['checkInAt'] as Timestamp
          : null,
      checkOutAt: data['checkOutAt'] is Timestamp
          ? data['checkOutAt'] as Timestamp
          : null,
      checkInMethod: (data['checkInMethod'] ?? '').toString().trim(),
      checkOutMethod: (data['checkOutMethod'] ?? '').toString().trim(),
      wifiSsid: (data['wifiSsid'] ?? '').toString().trim(),
      status: _readStatus(data['status']),
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? data['updatedAt'] as Timestamp
          : Timestamp.now(),
    );
  }

  factory AttendanceRecordModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AttendanceRecordModel.fromMap(
      doc.data() ?? <String, dynamic>{},
      id: doc.id,
    );
  }

  static String _readStatus(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (allowedStatuses.contains(value)) {
      return value;
    }
    return allowedStatuses.first;
  }

  bool get isCheckedOut => status == 'checkedOut' || checkOutAt != null;
  bool get isCheckedIn => !isCheckedOut;

  Map<String, dynamic> toMap() {
    return {
      'labId': labId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'dateKey': dateKey,
      'checkInAt': checkInAt,
      'checkOutAt': checkOutAt,
      'checkInMethod': checkInMethod,
      'checkOutMethod': checkOutMethod,
      'wifiSsid': wifiSsid,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AttendanceRecordModel copyWith({
    String? id,
    String? labId,
    String? userId,
    String? userName,
    String? userEmail,
    String? dateKey,
    Timestamp? checkInAt,
    bool clearCheckInAt = false,
    Timestamp? checkOutAt,
    bool clearCheckOutAt = false,
    String? checkInMethod,
    String? checkOutMethod,
    String? wifiSsid,
    String? status,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return AttendanceRecordModel(
      id: id ?? this.id,
      labId: labId ?? this.labId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      dateKey: dateKey ?? this.dateKey,
      checkInAt: clearCheckInAt ? null : (checkInAt ?? this.checkInAt),
      checkOutAt: clearCheckOutAt ? null : (checkOutAt ?? this.checkOutAt),
      checkInMethod: checkInMethod ?? this.checkInMethod,
      checkOutMethod: checkOutMethod ?? this.checkOutMethod,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
