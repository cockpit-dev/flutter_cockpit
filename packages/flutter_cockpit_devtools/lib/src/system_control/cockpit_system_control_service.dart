import 'cockpit_system_control_profile.dart';
import 'cockpit_system_control_adapter.dart';
import 'cockpit_system_control_registry.dart';

export 'cockpit_system_control_action.dart';
export 'cockpit_system_control_profile.dart';
export 'cockpit_system_control_registry.dart';

final class CockpitSystemControlDescribeRequest {
  const CockpitSystemControlDescribeRequest({
    required this.platform,
    this.deviceId,
    this.appId,
    this.processId,
  });

  final String platform;
  final String? deviceId;
  final String? appId;
  final int? processId;
}

final class CockpitSystemControlDescribeResult {
  const CockpitSystemControlDescribeResult({
    required this.profile,
    required this.recommendedNextStep,
  });

  final CockpitSystemControlProfile profile;
  final String recommendedNextStep;

  Map<String, Object?> toJson() => <String, Object?>{
    ...profile.toJson(),
    'recommendedNextStep': recommendedNextStep,
  };
}

typedef CockpitSystemControlDescribeFunction =
    Future<CockpitSystemControlDescribeResult> Function(
      CockpitSystemControlDescribeRequest request,
    );

final class CockpitSystemControlService {
  const CockpitSystemControlService({
    CockpitSystemControlRegistry registry =
        const CockpitSystemControlRegistry(),
  }) : _registry = registry;

  final CockpitSystemControlRegistry _registry;

  Future<CockpitSystemControlDescribeResult> describe(
    CockpitSystemControlDescribeRequest request,
  ) async {
    final adapter = _registry.resolve(request.platform);
    final profile = adapter.describe(
      CockpitSystemControlTargetContext(
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
      ),
    );
    return CockpitSystemControlDescribeResult(
      profile: profile,
      recommendedNextStep: profile.recommendedNextStep,
    );
  }
}
