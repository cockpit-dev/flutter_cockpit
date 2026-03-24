final class CockpitRemoteSessionLaunchOptions {
  const CockpitRemoteSessionLaunchOptions({
    required this.projectDir,
    required this.target,
    required this.platform,
    required this.deviceId,
    required this.sessionPort,
    this.launchTimeout = const Duration(seconds: 120),
  });

  final String projectDir;
  final String target;
  final String platform;
  final String deviceId;
  final int sessionPort;
  final Duration launchTimeout;
}
