import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../targets/cockpit_target_handle.dart';
import '../targets/cockpit_target_reference_resolver.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_read_app_service.dart';

typedef CockpitReadTargetFunction = Future<CockpitReadTargetResult> Function(
  CockpitReadTargetRequest request,
);
typedef CockpitReadFlutterTargetFunction = Future<CockpitReadAppResult>
    Function(
  CockpitReadAppRequest request,
);

final class CockpitReadTargetRequest {
  const CockpitReadTargetRequest({
    this.target,
    this.targetHandlePath,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.resultProfile = const CockpitInteractiveResultProfile.minimal(),
    this.snapshotOptions,
  });

  final CockpitTargetHandle? target;
  final String? targetHandlePath;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile resultProfile;
  final CockpitSnapshotOptions? snapshotOptions;
}

final class CockpitReadTargetResult {
  const CockpitReadTargetResult({
    required this.target,
    required this.capabilityProfile,
    required this.foregroundSurface,
    required this.selectedPlane,
    required this.fallbackTrail,
    required this.recommendedNextStep,
    this.whatMatters,
    this.sessionId,
    this.transportType,
    this.currentRouteName,
    this.uiSummary,
    this.snapshot,
    this.snapshotRef,
    this.effectiveSnapshotOptions,
  });

  final CockpitTargetHandle target;
  final CockpitCapabilityProfile capabilityProfile;
  final CockpitSurfaceKind foregroundSurface;
  final CockpitPlaneKind selectedPlane;
  final List<CockpitPlaneKind> fallbackTrail;
  final String recommendedNextStep;
  final String? whatMatters;
  final String? sessionId;
  final String? transportType;
  final String? currentRouteName;
  final CockpitInteractiveSnapshotSummary? uiSummary;
  final CockpitSnapshot? snapshot;
  final String? snapshotRef;
  final CockpitSnapshotOptions? effectiveSnapshotOptions;

  Map<String, Object?> toJson() => <String, Object?>{
        'target': target.toJson(),
        'capabilityProfile': capabilityProfile.toJson(),
        'foregroundSurface': foregroundSurface.name,
        'selectedPlane': selectedPlane.name,
        'fallbackTrail':
            fallbackTrail.map((planeKind) => planeKind.name).toList(),
        'recommendedNextStep': recommendedNextStep,
        if (whatMatters != null) 'whatMatters': whatMatters,
        if (sessionId != null) 'sessionId': sessionId,
        if (transportType != null) 'transportType': transportType,
        if (currentRouteName != null) 'currentRouteName': currentRouteName,
        if (uiSummary != null) 'uiSummary': uiSummary!.toJson(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (snapshotRef != null) 'snapshotRef': snapshotRef,
        if (effectiveSnapshotOptions != null)
          'effectiveSnapshotOptions': effectiveSnapshotOptions!.toJson(),
      };
}

final class CockpitReadTargetService {
  CockpitReadTargetService({
    CockpitReadTargetFunction? readTarget,
    CockpitReadAppService? readAppService,
    CockpitReadFlutterTargetFunction? readFlutterTarget,
    CockpitTargetReferenceResolver? targetReferenceResolver,
  })  : _readTargetOverride = readTarget,
        _readFlutterTarget = readFlutterTarget ??
            (readAppService ?? CockpitReadAppService()).read,
        _targetReferenceResolver =
            targetReferenceResolver ?? CockpitTargetReferenceResolver();

  final CockpitReadTargetFunction? _readTargetOverride;
  final CockpitReadFlutterTargetFunction _readFlutterTarget;
  final CockpitTargetReferenceResolver _targetReferenceResolver;

  Future<CockpitReadTargetResult> read(CockpitReadTargetRequest request) async {
    final override = _readTargetOverride;
    if (override != null) {
      return override(request);
    }

    final resolved = await _targetReferenceResolver.resolve(
      target: request.target,
      targetHandlePath: request.targetHandlePath,
      app: request.app,
      appHandlePath: request.appHandlePath,
      baseUri: request.baseUri,
      androidDeviceId: request.androidDeviceId,
    );
    final target = resolved.target;
    if (target == null || target.targetKind != CockpitTargetKind.flutterApp) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedTargetRead',
        message: 'read-target currently supports flutterApp targets only.',
      );
    }

    final appResult = await _readFlutterTarget(
      CockpitReadAppRequest(
        app: resolved.app,
        baseUri: resolved.baseUri,
        resultProfile: request.resultProfile,
        snapshotOptions: request.snapshotOptions,
      ),
    );
    final capabilityProfile = target.capabilityProfile ??
        appResult.capabilities.capabilityProfile ??
        _legacyCapabilityProfile(appResult.capabilities);
    return CockpitReadTargetResult(
      target: target.copyWith(capabilityProfile: capabilityProfile),
      capabilityProfile: capabilityProfile,
      foregroundSurface: CockpitSurfaceKind.flutterSemantic,
      selectedPlane: appResult.selectedPlane,
      fallbackTrail: appResult.fallbackTrail,
      recommendedNextStep: appResult.recommendedNextStep,
      whatMatters: appResult.whatMatters,
      sessionId: appResult.sessionId,
      transportType: appResult.transportType,
      currentRouteName: appResult.currentRouteName,
      uiSummary: appResult.uiSummary,
      snapshot: appResult.snapshot,
      snapshotRef: appResult.snapshotRef,
      effectiveSnapshotOptions: appResult.effectiveSnapshotOptions,
    );
  }

  static CockpitCapabilityProfile _legacyCapabilityProfile(
    CockpitCapabilities capabilities,
  ) {
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{
        if (capabilities.supportsInAppControl)
          CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.tap,
        CockpitActionCapability.typeText,
        if (capabilities.supportsNativeScreenCapture)
          CockpitActionCapability.captureScreenshot,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        if (capabilities.supportsFlutterViewCapture)
          CockpitEvidenceCapability.flutterScreenshot,
        if (capabilities.supportsNativeScreenCapture)
          CockpitEvidenceCapability.nativeScreenshot,
      },
    );
  }
}
