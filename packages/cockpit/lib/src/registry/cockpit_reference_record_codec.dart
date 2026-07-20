import 'cockpit_registry_records.dart';
import 'cockpit_registry_value_reader.dart';

abstract final class CockpitReferenceRecordCodec {
  static CockpitSessionReferenceRecord decodeSession(
    Object? value,
    String path,
  ) {
    final json = CockpitRegistryValueReader.object(value, path, const <String>{
      'sessionId',
      'workspaceId',
    });
    return CockpitSessionReferenceRecord(
      CockpitRegistryValueReader.id(json['sessionId'], '$path.sessionId'),
      CockpitRegistryValueReader.id(json['workspaceId'], '$path.workspaceId'),
    );
  }

  static Map<String, Object?> encodeSession(
    CockpitSessionReferenceRecord value,
  ) => <String, Object?>{
    'sessionId': value.sessionId,
    'workspaceId': value.workspaceId,
  };

  static CockpitRunReferenceRecord decodeRun(Object? value, String path) {
    final json = CockpitRegistryValueReader.object(value, path, const <String>{
      'runId',
      'workspaceId',
      'active',
      'retained',
      'artifactCount',
    });
    return CockpitRunReferenceRecord(
      runId: CockpitRegistryValueReader.id(json['runId'], '$path.runId'),
      workspaceId: CockpitRegistryValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      active: CockpitRegistryValueReader.boolean(
        json['active'],
        '$path.active',
      ),
      retained: CockpitRegistryValueReader.boolean(
        json['retained'],
        '$path.retained',
      ),
      artifactCount: CockpitRegistryValueReader.integer(
        json['artifactCount'],
        '$path.artifactCount',
      ),
    );
  }

  static Map<String, Object?> encodeRun(CockpitRunReferenceRecord value) =>
      <String, Object?>{
        'runId': value.runId,
        'workspaceId': value.workspaceId,
        'active': value.active,
        'retained': value.retained,
        'artifactCount': value.artifactCount,
      };

  static CockpitOtherReferenceRecord decodeOther(Object? value, String path) {
    final json = CockpitRegistryValueReader.object(value, path, const <String>{
      'owner',
      'referenceId',
      'workspaceId',
    });
    return CockpitOtherReferenceRecord(
      owner: CockpitRegistryValueReader.id(json['owner'], '$path.owner'),
      referenceId: CockpitRegistryValueReader.id(
        json['referenceId'],
        '$path.referenceId',
      ),
      workspaceId: CockpitRegistryValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
    );
  }

  static Map<String, Object?> encodeOther(CockpitOtherReferenceRecord value) =>
      <String, Object?>{
        'owner': value.owner,
        'referenceId': value.referenceId,
        'workspaceId': value.workspaceId,
      };

  static CockpitLatestRunRecord decodeLatest(Object? value, String path) {
    final json = CockpitRegistryValueReader.object(value, path, const <String>{
      'workspaceId',
      'runId',
    });
    return CockpitLatestRunRecord(
      CockpitRegistryValueReader.id(json['workspaceId'], '$path.workspaceId'),
      CockpitRegistryValueReader.id(json['runId'], '$path.runId'),
    );
  }

  static Map<String, Object?> encodeLatest(CockpitLatestRunRecord value) =>
      <String, Object?>{'workspaceId': value.workspaceId, 'runId': value.runId};

  static CockpitMarkerMutationRecord decodeMarkerMutation(
    Object? value,
    String path,
  ) {
    final json = CockpitRegistryValueReader.object(value, path, const <String>{
      'workspaceId',
      'expectedProjectId',
      'projectId',
    });
    return CockpitMarkerMutationRecord(
      workspaceId: CockpitRegistryValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      expectedProjectId: CockpitRegistryValueReader.id(
        json['expectedProjectId'],
        '$path.expectedProjectId',
      ),
      projectId: CockpitRegistryValueReader.id(
        json['projectId'],
        '$path.projectId',
      ),
    );
  }

  static Map<String, Object?> encodeMarkerMutation(
    CockpitMarkerMutationRecord value,
  ) => <String, Object?>{
    'workspaceId': value.workspaceId,
    'expectedProjectId': value.expectedProjectId,
    'projectId': value.projectId,
  };

  static CockpitRetiredWorkspaceIdentityRecord decodeRetiredIdentity(
    Object? value,
    String path,
  ) {
    final json = CockpitRegistryValueReader.object(value, path, const <String>{
      'workspaceId',
      'checkoutId',
    });
    return CockpitRetiredWorkspaceIdentityRecord(
      workspaceId: CockpitRegistryValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      checkoutId: CockpitRegistryValueReader.id(
        json['checkoutId'],
        '$path.checkoutId',
      ),
    );
  }

  static Map<String, Object?> encodeRetiredIdentity(
    CockpitRetiredWorkspaceIdentityRecord value,
  ) => <String, Object?>{
    'workspaceId': value.workspaceId,
    'checkoutId': value.checkoutId,
  };
}
