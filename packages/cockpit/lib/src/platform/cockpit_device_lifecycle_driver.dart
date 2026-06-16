import '../session/cockpit_remote_session_handle.dart';
import '../session/cockpit_remote_session_launch_options.dart';

abstract interface class CockpitDeviceLifecycleDriver {
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  );
}
