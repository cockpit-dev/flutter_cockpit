import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../foundation/cockpit_filesystem_identity.dart';

final class CockpitRootRecord {
  const CockpitRootRecord({
    required this.rootId,
    required this.canonicalPath,
    required this.filesystemIdentity,
    required this.identityQuality,
    required this.state,
    required this.registeredAt,
    required this.updatedAt,
    this.retiredAt,
  });

  final String rootId;
  final String canonicalPath;
  final String filesystemIdentity;
  final CockpitFilesystemIdentityQuality identityQuality;
  final CockpitRootState state;
  final DateTime registeredAt;
  final DateTime updatedAt;
  final DateTime? retiredAt;

  CockpitRootRecord copyWith({
    CockpitRootState? state,
    DateTime? updatedAt,
    DateTime? retiredAt,
  }) => CockpitRootRecord(
    rootId: rootId,
    canonicalPath: canonicalPath,
    filesystemIdentity: filesystemIdentity,
    identityQuality: identityQuality,
    state: state ?? this.state,
    registeredAt: registeredAt,
    updatedAt: updatedAt ?? this.updatedAt,
    retiredAt: retiredAt ?? this.retiredAt,
  );

  CockpitRootResource toResource() => CockpitRootResource(
    rootId: rootId,
    canonicalPath: canonicalPath,
    filesystemIdentity: filesystemIdentity,
    state: state,
    registeredAt: registeredAt,
    updatedAt: updatedAt,
    retiredAt: retiredAt,
  );
}

final class CockpitWorkspaceRecord {
  const CockpitWorkspaceRecord({
    required this.workspaceId,
    required this.projectId,
    required this.checkoutId,
    required this.rootId,
    required this.canonicalPath,
    required this.filesystemIdentity,
    required this.identityQuality,
    required this.state,
    required this.createdAt,
    required this.registeredAt,
    required this.updatedAt,
    this.retiredAt,
  });

  final String workspaceId;
  final String projectId;
  final String checkoutId;
  final String rootId;
  final String canonicalPath;
  final String filesystemIdentity;
  final CockpitFilesystemIdentityQuality identityQuality;
  final CockpitWorkspaceState state;
  final DateTime createdAt;
  final DateTime registeredAt;
  final DateTime updatedAt;
  final DateTime? retiredAt;

  CockpitWorkspaceRecord copyWith({
    String? workspaceId,
    String? projectId,
    String? checkoutId,
    String? rootId,
    String? canonicalPath,
    String? filesystemIdentity,
    CockpitFilesystemIdentityQuality? identityQuality,
    CockpitWorkspaceState? state,
    DateTime? updatedAt,
    DateTime? retiredAt,
  }) => CockpitWorkspaceRecord(
    workspaceId: workspaceId ?? this.workspaceId,
    projectId: projectId ?? this.projectId,
    checkoutId: checkoutId ?? this.checkoutId,
    rootId: rootId ?? this.rootId,
    canonicalPath: canonicalPath ?? this.canonicalPath,
    filesystemIdentity: filesystemIdentity ?? this.filesystemIdentity,
    identityQuality: identityQuality ?? this.identityQuality,
    state: state ?? this.state,
    createdAt: createdAt,
    registeredAt: registeredAt,
    updatedAt: updatedAt ?? this.updatedAt,
    retiredAt: retiredAt ?? this.retiredAt,
  );

  CockpitWorkspaceResource toResource() => CockpitWorkspaceResource(
    workspaceId: workspaceId,
    projectId: projectId,
    checkoutId: checkoutId,
    rootId: rootId,
    canonicalPath: canonicalPath,
    filesystemIdentity: filesystemIdentity,
    state: state,
    registeredAt: registeredAt,
    updatedAt: updatedAt,
  );
}

final class CockpitSessionReferenceRecord {
  const CockpitSessionReferenceRecord(this.sessionId, this.workspaceId);

  final String sessionId;
  final String workspaceId;
}

final class CockpitRunReferenceRecord {
  const CockpitRunReferenceRecord({
    required this.runId,
    required this.workspaceId,
    required this.active,
    required this.retained,
    required this.artifactCount,
  });

  final String runId;
  final String workspaceId;
  final bool active;
  final bool retained;
  final int artifactCount;
}

final class CockpitOtherReferenceRecord {
  const CockpitOtherReferenceRecord({
    required this.owner,
    required this.referenceId,
    required this.workspaceId,
  });

  final String owner;
  final String referenceId;
  final String workspaceId;
}

final class CockpitLatestRunRecord {
  const CockpitLatestRunRecord(this.workspaceId, this.runId);

  final String workspaceId;
  final String runId;
}

final class CockpitMarkerMutationRecord {
  const CockpitMarkerMutationRecord({
    required this.workspaceId,
    required this.expectedProjectId,
    required this.projectId,
  });

  final String workspaceId;
  final String expectedProjectId;
  final String projectId;
}

final class CockpitRetiredWorkspaceIdentityRecord {
  const CockpitRetiredWorkspaceIdentityRecord({
    required this.workspaceId,
    required this.checkoutId,
  });

  final String workspaceId;
  final String checkoutId;
}
