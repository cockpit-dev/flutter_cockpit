import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../foundation/cockpit_filesystem_identity.dart';
import 'cockpit_registry_records.dart';
import 'cockpit_registry_value_reader.dart';

abstract final class CockpitRegistryRecordCodec {
  static const _rootFields = <String>{
    'rootId',
    'canonicalPath',
    'filesystemIdentity',
    'identityQuality',
    'state',
    'registeredAt',
    'updatedAt',
    'retiredAt',
  };
  static const _workspaceFields = <String>{
    'workspaceId',
    'projectId',
    'checkoutId',
    'rootId',
    'canonicalPath',
    'filesystemIdentity',
    'identityQuality',
    'state',
    'createdAt',
    'registeredAt',
    'updatedAt',
    'retiredAt',
  };

  static Map<String, Object?> encodeRoot(CockpitRootRecord value) =>
      <String, Object?>{
        'rootId': value.rootId,
        'canonicalPath': value.canonicalPath,
        'filesystemIdentity': value.filesystemIdentity,
        'identityQuality': value.identityQuality.name,
        'state': value.state.name,
        'registeredAt': value.registeredAt.toIso8601String(),
        'updatedAt': value.updatedAt.toIso8601String(),
        'retiredAt': value.retiredAt?.toIso8601String(),
      };

  static CockpitRootRecord decodeRoot(Object? value, String path) {
    final json = CockpitRegistryValueReader.object(value, path, _rootFields);
    final state = CockpitRegistryValueReader.enumeration(
      json['state'],
      '$path.state',
      CockpitRootState.values,
    );
    final retiredAt = _optionalTimestamp(json['retiredAt'], '$path.retiredAt');
    if ((state == CockpitRootState.retired) != (retiredAt != null)) {
      throw FormatException('Inconsistent root retirement at $path.');
    }
    final record = CockpitRootRecord(
      rootId: CockpitRegistryValueReader.id(json['rootId'], '$path.rootId'),
      canonicalPath: CockpitRegistryValueReader.string(
        json['canonicalPath'],
        '$path.canonicalPath',
      ),
      filesystemIdentity: CockpitRegistryValueReader.string(
        json['filesystemIdentity'],
        '$path.filesystemIdentity',
        maximum: 512,
      ),
      identityQuality: CockpitRegistryValueReader.enumeration(
        json['identityQuality'],
        '$path.identityQuality',
        CockpitFilesystemIdentityQuality.values,
      ),
      state: state,
      registeredAt: CockpitRegistryValueReader.timestamp(
        json['registeredAt'],
        '$path.registeredAt',
      ),
      updatedAt: CockpitRegistryValueReader.timestamp(
        json['updatedAt'],
        '$path.updatedAt',
      ),
      retiredAt: retiredAt,
    );
    record.toResource();
    return record;
  }

  static Map<String, Object?> encodeWorkspace(CockpitWorkspaceRecord value) =>
      <String, Object?>{
        'workspaceId': value.workspaceId,
        'projectId': value.projectId,
        'checkoutId': value.checkoutId,
        'rootId': value.rootId,
        'canonicalPath': value.canonicalPath,
        'filesystemIdentity': value.filesystemIdentity,
        'identityQuality': value.identityQuality.name,
        'state': value.state.name,
        'createdAt': value.createdAt.toIso8601String(),
        'registeredAt': value.registeredAt.toIso8601String(),
        'updatedAt': value.updatedAt.toIso8601String(),
        'retiredAt': value.retiredAt?.toIso8601String(),
      };

  static CockpitWorkspaceRecord decodeWorkspace(Object? value, String path) {
    final json = CockpitRegistryValueReader.object(
      value,
      path,
      _workspaceFields,
    );
    final state = CockpitRegistryValueReader.enumeration(
      json['state'],
      '$path.state',
      CockpitWorkspaceState.values,
    );
    final retiredAt = _optionalTimestamp(json['retiredAt'], '$path.retiredAt');
    if ((state == CockpitWorkspaceState.retired) != (retiredAt != null)) {
      throw FormatException('Inconsistent workspace retirement at $path.');
    }
    final record = CockpitWorkspaceRecord(
      workspaceId: CockpitRegistryValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      projectId: CockpitRegistryValueReader.id(
        json['projectId'],
        '$path.projectId',
      ),
      checkoutId: CockpitRegistryValueReader.id(
        json['checkoutId'],
        '$path.checkoutId',
      ),
      rootId: CockpitRegistryValueReader.id(json['rootId'], '$path.rootId'),
      canonicalPath: CockpitRegistryValueReader.string(
        json['canonicalPath'],
        '$path.canonicalPath',
      ),
      filesystemIdentity: CockpitRegistryValueReader.string(
        json['filesystemIdentity'],
        '$path.filesystemIdentity',
        maximum: 512,
      ),
      identityQuality: CockpitRegistryValueReader.enumeration(
        json['identityQuality'],
        '$path.identityQuality',
        CockpitFilesystemIdentityQuality.values,
      ),
      state: state,
      createdAt: CockpitRegistryValueReader.timestamp(
        json['createdAt'],
        '$path.createdAt',
      ),
      registeredAt: CockpitRegistryValueReader.timestamp(
        json['registeredAt'],
        '$path.registeredAt',
      ),
      updatedAt: CockpitRegistryValueReader.timestamp(
        json['updatedAt'],
        '$path.updatedAt',
      ),
      retiredAt: retiredAt,
    );
    record.toResource();
    return record;
  }

  static DateTime? _optionalTimestamp(Object? value, String path) =>
      value == null ? null : CockpitRegistryValueReader.timestamp(value, path);
}
