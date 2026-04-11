import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_read_remote_status_service.dart';
import 'cockpit_session_registry.dart';

final class CockpitReadAppRequest {
  const CockpitReadAppRequest({
    this.appId,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.resultProfile = const CockpitInteractiveResultProfile.minimal(),
    this.snapshotOptions,
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile resultProfile;
  final CockpitSnapshotOptions? snapshotOptions;
}

final class CockpitReadAppResult {
  const CockpitReadAppResult({
    required this.sessionId,
    required this.transportType,
    required this.capabilities,
    required this.recordingCapabilities,
    this.selectedPlane = CockpitPlaneKind.flutterSemanticPlane,
    this.fallbackTrail = const <CockpitPlaneKind>[],
    this.recommendedNextStep = 'runNextCommand',
    this.whatMatters,
    this.app,
    this.state,
    this.lastError,
    this.currentRouteName,
    this.uiSummary,
    this.snapshot,
    this.snapshotRef,
    this.diagnostics,
    this.effectiveSnapshotOptions,
  });

  final String sessionId;
  final String transportType;
  final CockpitCapabilities capabilities;
  final CockpitRecordingCapabilities recordingCapabilities;
  final CockpitPlaneKind selectedPlane;
  final List<CockpitPlaneKind> fallbackTrail;
  final String recommendedNextStep;
  final String? whatMatters;
  final CockpitAppHandle? app;
  final String? state;
  final String? lastError;
  final String? currentRouteName;
  final CockpitInteractiveSnapshotSummary? uiSummary;
  final CockpitSnapshot? snapshot;
  final String? snapshotRef;
  final Map<String, Object?>? diagnostics;
  final CockpitSnapshotOptions? effectiveSnapshotOptions;

  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'transportType': transportType,
        'capabilities': capabilities.toJson(),
        'recordingCapabilities': recordingCapabilities.toJson(),
        'selectedPlane': selectedPlane.name,
        'fallbackTrail':
            fallbackTrail.map((planeKind) => planeKind.name).toList(),
        'recommendedNextStep': recommendedNextStep,
        if (whatMatters != null) 'whatMatters': whatMatters,
        if (app != null) 'app': app!.toJson(),
        if (state != null) 'state': state,
        if (lastError != null) 'lastError': lastError,
        if (currentRouteName != null) 'currentRouteName': currentRouteName,
        if (uiSummary != null) 'uiSummary': uiSummary!.toJson(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (snapshotRef != null) 'snapshotRef': snapshotRef,
        if (diagnostics != null) 'diagnostics': diagnostics,
        if (effectiveSnapshotOptions != null)
          'effectiveSnapshotOptions': effectiveSnapshotOptions!.toJson(),
      };
}

final class CockpitReadAppService {
  CockpitReadAppService({
    CockpitReadRemoteStatusService? remoteStatusService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  })  : _remoteStatusService =
            remoteStatusService ?? CockpitReadRemoteStatusService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry);

  final CockpitReadRemoteStatusService _remoteStatusService;
  final CockpitAppReferenceResolver _appReferenceResolver;

  Future<CockpitReadAppResult> read(CockpitReadAppRequest request) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
      baseUri: request.baseUri,
      androidDeviceId: request.androidDeviceId,
    );
    final result = await _remoteStatusService.read(
      CockpitReadRemoteStatusRequest(
        baseUri: resolved.baseUri,
        resultProfile: request.resultProfile,
        snapshotOptions: request.snapshotOptions,
      ),
    );

    return CockpitReadAppResult(
      sessionId: result.sessionId,
      transportType: result.transportType,
      capabilities: result.capabilities,
      recordingCapabilities: result.recordingCapabilities,
      selectedPlane: _selectedPlaneFor(result.capabilities),
      fallbackTrail: _fallbackTrailFor(result.capabilities),
      recommendedNextStep: _recommendedNextStep(
        currentRouteName: result.currentRouteName,
        lastError: resolved.developmentRecord?.status.lastError,
      ),
      whatMatters: _whatMatters(
        currentRouteName: result.currentRouteName,
        lastError: resolved.developmentRecord?.status.lastError,
      ),
      app: resolved.app,
      state: resolved.developmentRecord?.status.state.jsonValue ??
          resolved.remoteRecord?.recommendedNextStep,
      lastError: resolved.developmentRecord?.status.lastError,
      currentRouteName: result.currentRouteName,
      uiSummary: result.uiSummary,
      snapshot: result.snapshot,
      snapshotRef: result.snapshotRef,
      diagnostics: null,
      effectiveSnapshotOptions: result.effectiveSnapshotOptions,
    );
  }

  static CockpitPlaneKind _selectedPlaneFor(CockpitCapabilities capabilities) {
    if (capabilities.supportsInAppControl) {
      return CockpitPlaneKind.flutterSemanticPlane;
    }
    if (capabilities.supportsHostAutomation) {
      return CockpitPlaneKind.hostPlane;
    }
    if (capabilities.supportsNativeScreenCapture) {
      return CockpitPlaneKind.nativeUiPlane;
    }
    return CockpitPlaneKind.deviceSystemPlane;
  }

  static List<CockpitPlaneKind> _fallbackTrailFor(
    CockpitCapabilities capabilities,
  ) {
    return switch (_selectedPlaneFor(capabilities)) {
      CockpitPlaneKind.flutterSemanticPlane => <CockpitPlaneKind>[
          CockpitPlaneKind.nativeUiPlane,
          CockpitPlaneKind.deviceSystemPlane,
        ],
      CockpitPlaneKind.hostPlane => const <CockpitPlaneKind>[],
      CockpitPlaneKind.nativeUiPlane => <CockpitPlaneKind>[
          CockpitPlaneKind.deviceSystemPlane,
        ],
      CockpitPlaneKind.deviceSystemPlane => const <CockpitPlaneKind>[],
    };
  }

  static String _recommendedNextStep({
    required String? currentRouteName,
    required String? lastError,
  }) {
    if (lastError != null && lastError.isNotEmpty) {
      return 'inspectFailureDiagnostics';
    }
    if (currentRouteName != null && currentRouteName.isNotEmpty) {
      return 'runNextCommand';
    }
    return 'inspectCurrentState';
  }

  static String? _whatMatters({
    required String? currentRouteName,
    required String? lastError,
  }) {
    if (lastError != null && lastError.isNotEmpty) {
      return lastError;
    }
    if (currentRouteName != null && currentRouteName.isNotEmpty) {
      return 'Current route is $currentRouteName.';
    }
    return null;
  }
}
