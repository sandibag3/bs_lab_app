import 'package:cloud_firestore/cloud_firestore.dart';

class NotebookExperimentModel {
  final String id;
  final String experimentCode;
  final String title;
  final Timestamp date;
  final String aim;
  final String reactionTitle;
  final String startingMaterial;
  final String reagents;
  final String catalyst;
  final String solvent;
  final String temperature;
  final String time;
  final String atmosphere;
  final String scale;
  final String procedure;
  final String observations;
  final String workup;
  final String purification;
  final String yieldText;
  final String characterization;
  final String conclusion;
  final String status;
  final String ownerUid;
  final String ownerEmail;
  final String createdBy;
  final String userEmail;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String labId;
  final String projectId;

  const NotebookExperimentModel({
    required this.id,
    required this.experimentCode,
    required this.title,
    required this.date,
    required this.aim,
    required this.reactionTitle,
    required this.startingMaterial,
    required this.reagents,
    required this.catalyst,
    required this.solvent,
    required this.temperature,
    required this.time,
    required this.atmosphere,
    required this.scale,
    required this.procedure,
    required this.observations,
    required this.workup,
    required this.purification,
    required this.yieldText,
    required this.characterization,
    required this.conclusion,
    required this.status,
    required this.ownerUid,
    required this.ownerEmail,
    required this.createdBy,
    required this.userEmail,
    required this.createdAt,
    required this.updatedAt,
    required this.labId,
    required this.projectId,
  });

  factory NotebookExperimentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return NotebookExperimentModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory NotebookExperimentModel.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    final fallbackTimestamp = Timestamp.now();

    Timestamp readTimestamp(String key) {
      final value = data[key];
      if (value is Timestamp) {
        return value;
      }
      return fallbackTimestamp;
    }

    return NotebookExperimentModel(
      id: id,
      experimentCode: (data['experimentCode'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      date: readTimestamp('date'),
      aim: (data['aim'] ?? '').toString(),
      reactionTitle: (data['reactionTitle'] ?? '').toString(),
      startingMaterial: (data['startingMaterial'] ?? '').toString(),
      reagents: (data['reagents'] ?? '').toString(),
      catalyst: (data['catalyst'] ?? '').toString(),
      solvent: (data['solvent'] ?? '').toString(),
      temperature: (data['temperature'] ?? '').toString(),
      time: (data['time'] ?? '').toString(),
      atmosphere: (data['atmosphere'] ?? '').toString(),
      scale: (data['scale'] ?? '').toString(),
      procedure: (data['procedure'] ?? '').toString(),
      observations: (data['observations'] ?? '').toString(),
      workup: (data['workup'] ?? '').toString(),
      purification: (data['purification'] ?? '').toString(),
      yieldText: (data['yieldText'] ?? '').toString(),
      characterization: (data['characterization'] ?? '').toString(),
      conclusion: (data['conclusion'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      ownerUid: (data['ownerUid'] ?? '').toString(),
      ownerEmail: (data['ownerEmail'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      createdAt: readTimestamp('createdAt'),
      updatedAt: readTimestamp('updatedAt'),
      labId: (data['labId'] ?? '').toString(),
      projectId: (data['projectId'] ?? '').toString(),
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
      'experimentCode': experimentCode,
      'title': title,
      'date': date,
      'aim': aim,
      'reactionTitle': reactionTitle,
      'startingMaterial': startingMaterial,
      'reagents': reagents,
      'catalyst': catalyst,
      'solvent': solvent,
      'temperature': temperature,
      'time': time,
      'atmosphere': atmosphere,
      'scale': scale,
      'procedure': procedure,
      'observations': observations,
      'workup': workup,
      'purification': purification,
      'yieldText': yieldText,
      'characterization': characterization,
      'conclusion': conclusion,
      'status': status,
      'ownerUid': ownerUid,
      'ownerEmail': ownerEmail,
      'createdBy': createdBy,
      'userEmail': userEmail,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'labId': labId,
      'projectId': projectId,
    };
  }
}
