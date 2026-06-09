import 'cockpit_system_control_profile.dart';
import 'cockpit_system_control_adapter.dart';
import 'cockpit_ios_webdriver_agent_client.dart';
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
    this.metadata = const <String, Object?>{},
  });

  final String platform;
  final String? deviceId;
  final String? appId;
  final int? processId;
  final Map<String, Object?> metadata;
}

final class CockpitSystemControlDescribeResult {
  const CockpitSystemControlDescribeResult({
    required this.profile,
    required this.recommendedNextStep,
    this.metadata = const <String, Object?>{},
  });

  final CockpitSystemControlProfile profile;
  final String recommendedNextStep;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    ...profile.toJson(),
    if (metadata.isNotEmpty) 'metadata': metadata,
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
    CockpitIosWdaEndpointProbe iosWdaEndpointProbe = cockpitProbeIosWdaEndpoint,
  }) : _registry = registry,
       _iosWdaEndpointProbe = iosWdaEndpointProbe;

  final CockpitSystemControlRegistry _registry;
  final CockpitIosWdaEndpointProbe _iosWdaEndpointProbe;

  Future<CockpitSystemControlDescribeResult> describe(
    CockpitSystemControlDescribeRequest request,
  ) async {
    final adapter = _registry.resolve(request.platform);
    final metadata = await _resolvedMetadata(request);
    final profile = adapter.describe(
      CockpitSystemControlTargetContext(
        deviceId: request.deviceId,
        appId: request.appId,
        processId: request.processId,
        metadata: metadata,
      ),
    );
    return CockpitSystemControlDescribeResult(
      profile: profile,
      recommendedNextStep: profile.recommendedNextStep,
      metadata: metadata,
    );
  }

  Future<Map<String, Object?>> _resolvedMetadata(
    CockpitSystemControlDescribeRequest request,
  ) async {
    final metadata = <String, Object?>{...request.metadata};
    if (request.platform.trim().toLowerCase() != 'ios' ||
        !_looksLikeIosSimulatorDeviceId(request.deviceId)) {
      return metadata;
    }
    final wdaUrl = metadata['wdaUrl'];
    if (wdaUrl is! String || wdaUrl.trim().isEmpty) {
      return _discoverLocalWdaMetadata(metadata);
    }
    return _resolveExplicitWdaMetadata(metadata, wdaUrl.trim());
  }

  Future<Map<String, Object?>> _discoverLocalWdaMetadata(
    Map<String, Object?> metadata,
  ) async {
    for (final uri in _defaultIosWdaUris) {
      final reachable = await _iosWdaEndpointProbe(
        uri,
        timeout: const Duration(milliseconds: 250),
      );
      if (reachable) {
        metadata['wdaUrl'] = uri.toString();
        metadata['wdaReachable'] = true;
        metadata['wdaDiscovered'] = true;
        return metadata;
      }
    }
    metadata['wdaReachable'] = false;
    metadata['wdaFailureReason'] = 'wdaEndpointNotConfigured';
    return metadata;
  }

  Future<Map<String, Object?>> _resolveExplicitWdaMetadata(
    Map<String, Object?> metadata,
    String wdaUrl,
  ) async {
    if (wdaUrl.isEmpty) {
      return metadata;
    }
    final uri = Uri.tryParse(wdaUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      metadata['wdaReachable'] = false;
      metadata['wdaFailureReason'] = 'invalidWdaUrl';
      return metadata;
    }
    final reachable = await _iosWdaEndpointProbe(
      uri,
      timeout: const Duration(seconds: 2),
    );
    metadata['wdaReachable'] = reachable;
    if (!reachable) {
      metadata['wdaFailureReason'] = 'wdaEndpointUnreachable';
    }
    return metadata;
  }

  bool _looksLikeIosSimulatorDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      return false;
    }
    if (deviceId.toLowerCase() == 'booted') {
      return true;
    }
    return RegExp(
      r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
    ).hasMatch(deviceId);
  }
}

final List<Uri> _defaultIosWdaUris = <Uri>[
  Uri.parse('http://127.0.0.1:8100'),
  Uri.parse('http://localhost:8100'),
];
