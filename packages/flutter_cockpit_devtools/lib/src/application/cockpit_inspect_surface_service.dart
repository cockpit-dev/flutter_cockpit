import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../targets/cockpit_target_handle.dart';
import '../targets/cockpit_target_reference_resolver.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_inspect_ui_service.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_read_target_service.dart';

typedef CockpitInspectSurfaceFunction = Future<CockpitInspectSurfaceResult>
    Function(
  CockpitInspectSurfaceRequest request,
);
typedef CockpitInspectFlutterSurfaceFunction = Future<CockpitInspectUiResult>
    Function(
  CockpitInspectUiRequest request,
);

final class CockpitInspectSurfaceRequest {
  const CockpitInspectSurfaceRequest({
    this.target,
    this.targetHandlePath,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.resultProfile = const CockpitInteractiveResultProfile.inspect(),
    this.snapshotOptions,
    this.compareAgainstSnapshotRef,
  });

  final CockpitTargetHandle? target;
  final String? targetHandlePath;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile resultProfile;
  final CockpitSnapshotOptions? snapshotOptions;
  final String? compareAgainstSnapshotRef;
}

final class CockpitInspectSurfaceResult {
  const CockpitInspectSurfaceResult({
    required this.target,
    required this.capabilityProfile,
    required this.surfaceKind,
    required this.selectedPlane,
    required this.recommendedNextStep,
    required this.diagnosticLevel,
    required this.truncated,
    this.routeName,
    this.uiSummary,
    this.snapshot,
    this.diagnostics,
    this.delta,
    this.snapshotRef,
    this.effectiveSnapshotOptions,
  });

  final CockpitTargetHandle target;
  final CockpitCapabilityProfile capabilityProfile;
  final CockpitSurfaceKind surfaceKind;
  final CockpitPlaneKind selectedPlane;
  final String recommendedNextStep;
  final String? routeName;
  final String diagnosticLevel;
  final bool truncated;
  final CockpitInteractiveSnapshotSummary? uiSummary;
  final CockpitSnapshot? snapshot;
  final Map<String, Object?>? diagnostics;
  final CockpitInteractiveSnapshotDelta? delta;
  final String? snapshotRef;
  final CockpitSnapshotOptions? effectiveSnapshotOptions;

  Map<String, Object?> toJson() => <String, Object?>{
        'target': target.toJson(),
        'capabilityProfile': capabilityProfile.toJson(),
        'surfaceKind': surfaceKind.name,
        'selectedPlane': selectedPlane.name,
        'recommendedNextStep': recommendedNextStep,
        if (routeName != null) 'routeName': routeName,
        'diagnosticLevel': diagnosticLevel,
        'truncated': truncated,
        if (uiSummary != null) 'uiSummary': uiSummary!.toJson(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (diagnostics != null) 'diagnostics': diagnostics,
        if (delta != null) 'delta': delta!.toJson(),
        if (snapshotRef != null) 'snapshotRef': snapshotRef,
        if (effectiveSnapshotOptions != null)
          'effectiveSnapshotOptions': effectiveSnapshotOptions!.toJson(),
      };
}

final class CockpitInspectSurfaceService {
  CockpitInspectSurfaceService({
    CockpitInspectSurfaceFunction? inspectSurface,
    CockpitInspectUiService? inspectUiService,
    CockpitInspectFlutterSurfaceFunction? inspectFlutterSurface,
    CockpitTargetReferenceResolver? targetReferenceResolver,
  })  : _inspectSurfaceOverride = inspectSurface,
        _inspectFlutterSurface = inspectFlutterSurface ??
            (inspectUiService ?? CockpitInspectUiService()).inspect,
        _targetReferenceResolver =
            targetReferenceResolver ?? CockpitTargetReferenceResolver();

  final CockpitInspectSurfaceFunction? _inspectSurfaceOverride;
  final CockpitInspectFlutterSurfaceFunction _inspectFlutterSurface;
  final CockpitTargetReferenceResolver _targetReferenceResolver;

  Future<CockpitInspectSurfaceResult> inspect(
    CockpitInspectSurfaceRequest request,
  ) async {
    final override = _inspectSurfaceOverride;
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
        code: 'unsupportedInspectSurface',
        message: 'inspect-surface currently supports flutterApp targets only.',
      );
    }

    final inspectResult = await _inspectFlutterSurface(
      CockpitInspectUiRequest(
        app: resolved.app,
        baseUri: resolved.baseUri,
        resultProfile: request.resultProfile,
        snapshotOptions: request.snapshotOptions,
        compareAgainstSnapshotRef: request.compareAgainstSnapshotRef,
      ),
    );
    final capabilityProfile =
        target.capabilityProfile ?? _legacyCapabilityProfile(target.platform);
    return CockpitInspectSurfaceResult(
      target: target.copyWith(capabilityProfile: capabilityProfile),
      capabilityProfile: capabilityProfile,
      surfaceKind: CockpitSurfaceKind.flutterSemantic,
      selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
      recommendedNextStep: 'runNextCommand',
      routeName: inspectResult.routeName,
      diagnosticLevel: inspectResult.diagnosticLevel,
      truncated: inspectResult.truncated,
      uiSummary: inspectResult.uiSummary,
      snapshot: inspectResult.snapshot,
      diagnostics: inspectResult.diagnostics,
      delta: inspectResult.delta,
      snapshotRef: inspectResult.snapshotRef,
      effectiveSnapshotOptions: inspectResult.effectiveSnapshotOptions,
    );
  }

  static CockpitCapabilityProfile _legacyCapabilityProfile(String platform) {
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.tap,
        CockpitActionCapability.typeText,
        CockpitActionCapability.captureScreenshot,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.flutterScreenshot,
        CockpitEvidenceCapability.nativeScreenshot,
      },
      qualityFlags: platform == 'ios'
          ? <CockpitQualityFlag>{CockpitQualityFlag.simulatorOnly}
          : const <CockpitQualityFlag>{},
    );
  }
}
