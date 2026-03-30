import 'cockpit_session_registry.dart';

final class CockpitListActiveSessionsService {
  const CockpitListActiveSessionsService(
      {required CockpitSessionRegistry registry})
      : _registry = registry;

  final CockpitSessionRegistry _registry;

  CockpitActiveSessionsSnapshot list() => _registry.snapshot();
}
