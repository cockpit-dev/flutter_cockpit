import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../registry/cockpit_workspace_registry.dart';
import 'cockpit_lease_support.dart';

final class CockpitRegistryLeaseWorkspaceAuthority
    implements CockpitLeaseWorkspaceAuthority {
  const CockpitRegistryLeaseWorkspaceAuthority(this._workspaces);

  final CockpitWorkspaceRegistry _workspaces;

  @override
  Future<CockpitLeaseWorkspaceScope> resolveActive(String workspaceId) async {
    final workspace = await _workspaces.get(workspaceId);
    if (workspace.state != CockpitWorkspaceState.active) {
      throw const CockpitLeaseException(
        code: 'workspaceNotActive',
        message: 'Workspace does not grant lease authority.',
      );
    }
    return CockpitLeaseWorkspaceScope(
      workspaceId: workspace.workspaceId,
      rootId: workspace.rootId,
    );
  }
}
