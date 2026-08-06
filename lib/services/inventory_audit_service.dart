import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_state.dart';
import 'person_display_resolver.dart';

class InventoryAuditService {
  const InventoryAuditService._();

  static Map<String, dynamic> createAuditFields({Object? timestamp}) {
    final auditTimestamp = timestamp ?? FieldValue.serverTimestamp();
    final actor = _currentActor();

    return {
      'createdByUid': actor.uid,
      'createdByName': actor.name,
      'createdAt': auditTimestamp,
      'lastModifiedByUid': actor.uid,
      'lastModifiedByName': actor.name,
      'lastModifiedAt': auditTimestamp,
    };
  }

  static Map<String, dynamic> updateAuditFields({Object? timestamp}) {
    final auditTimestamp = timestamp ?? FieldValue.serverTimestamp();
    final actor = _currentActor();

    return {
      'lastModifiedByUid': actor.uid,
      'lastModifiedByName': actor.name,
      'lastModifiedAt': auditTimestamp,
    };
  }

  static _InventoryAuditActor _currentActor() {
    final appState = AppState.instance;
    final uid = appState.authenticatedUserId.trim();
    final name = PersonDisplayResolver.currentUserDisplayName().trim();

    return _InventoryAuditActor(uid: uid, name: name.isEmpty ? 'User' : name);
  }
}

class _InventoryAuditActor {
  final String uid;
  final String name;

  const _InventoryAuditActor({required this.uid, required this.name});
}
