import '../mcp/core/cockpit_mcp_roots_tracker.dart';

final class CockpitListWorkspaceRootsService {
  const CockpitListWorkspaceRootsService({
    required CockpitMcpRootsTracker rootsTracker,
  }) : _rootsTracker = rootsTracker;

  final CockpitMcpRootsTracker _rootsTracker;

  Map<String, Object?> list() => _rootsTracker.toJson();
}
