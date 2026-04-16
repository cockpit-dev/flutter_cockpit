import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:collection/collection.dart';

import '../platform/cockpit_platform_driver_registry.dart';
import '../targets/cockpit_target_capability_support.dart';
import '../targets/cockpit_target_handle.dart';
import '../targets/cockpit_target_reference_resolver.dart';
import '../capture/cockpit_host_capture_adapter.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_inspect_ui_service.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_result_profile.dart';

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
    CockpitPlatformDriverRegistry? platformDriverRegistry,
  })  : _inspectSurfaceOverride = inspectSurface,
        _inspectFlutterSurface = inspectFlutterSurface ??
            (inspectUiService ?? CockpitInspectUiService()).inspect,
        _targetReferenceResolver =
            targetReferenceResolver ?? CockpitTargetReferenceResolver(),
        _platformDriverRegistry =
            platformDriverRegistry ?? CockpitPlatformDriverRegistry();

  final CockpitInspectSurfaceFunction? _inspectSurfaceOverride;
  final CockpitInspectFlutterSurfaceFunction _inspectFlutterSurface;
  final CockpitTargetReferenceResolver _targetReferenceResolver;
  final CockpitPlatformDriverRegistry _platformDriverRegistry;

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
    if (target == null) {
      throw CockpitApplicationServiceException(
        code: 'missingTargetReference',
        message: 'inspect-surface requires a resolved target handle.',
      );
    }

    final capabilityProfile = await _resolveCapabilityProfile(target);
    final flutterInspectResult = await _tryFlutterRemoteInspect(
      request: request,
      target: target,
      resolved: resolved,
      capabilityProfile: capabilityProfile,
    );
    if (flutterInspectResult != null) {
      return flutterInspectResult;
    }

    final evidenceDriver = _platformDriverRegistry.resolveEvidenceDriver(
      platform: target.platform,
      deviceId: target.deviceId,
    );
    final captureAdapter = evidenceDriver?.captureAdapter;
    if (captureAdapter is CockpitHostCaptureAdapter) {
      final capture = await captureAdapter.capture(
        CockpitCommand(
          commandId: 'inspect-surface-capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.afterAction,
            name: 'inspect_surface_${target.platform}',
          ),
        ),
      );
      if (!capture.result.success) {
        throw CockpitApplicationServiceException(
          code: 'surfaceCaptureFailed',
          message: capture.result.error?.message ??
              'Unable to capture the current target surface.',
          details: capture.result.error?.details ?? const <String, Object?>{},
        );
      }
      final artifactDescriptors = _artifactDescriptorsFromExecution(capture);
      final snapshotRef = capture.artifactSourcePaths.values.firstOrNull ??
          artifactDescriptors.firstOrNull?.relativePath;
      final selectedPlane = cockpitPlaneForSurface(
        cockpitForegroundSurfaceForTargetProfile(capabilityProfile),
      );
      return CockpitInspectSurfaceResult(
        target: target.copyWith(capabilityProfile: capabilityProfile),
        capabilityProfile: capabilityProfile,
        surfaceKind:
            cockpitForegroundSurfaceForTargetProfile(capabilityProfile),
        selectedPlane: selectedPlane,
        recommendedNextStep: 'reviewCapture',
        diagnosticLevel: request.resultProfile.snapshotProfile.jsonValue,
        truncated: false,
        uiSummary: _staticSummaryForProfile(request.resultProfile),
        diagnostics: <String, Object?>{
          'capture':
              CockpitInteractiveCommandCore.fromResult(capture.result).toJson(),
          'artifacts': artifactDescriptors
              .map((artifact) => artifact.toJson())
              .toList(growable: false),
        },
        snapshotRef: snapshotRef,
      );
    }

    final selectedPlane = cockpitPlaneForSurface(
      cockpitForegroundSurfaceForTargetProfile(capabilityProfile),
    );
    return CockpitInspectSurfaceResult(
      target: target.copyWith(capabilityProfile: capabilityProfile),
      capabilityProfile: capabilityProfile,
      surfaceKind: cockpitForegroundSurfaceForTargetProfile(capabilityProfile),
      selectedPlane: selectedPlane,
      recommendedNextStep: cockpitRecommendedNextStepForProfile(
        capabilityProfile,
      ),
      diagnosticLevel: request.resultProfile.snapshotProfile.jsonValue,
      truncated: false,
      uiSummary: _staticSummaryForProfile(request.resultProfile),
      diagnostics: <String, Object?>{
        'reason': 'No host capture adapter is available for this target.',
      },
    );
  }

  static CockpitCapabilityProfile _legacyCapabilityProfile() {
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
    );
  }

  Future<CockpitCapabilityProfile> _resolveCapabilityProfile(
    CockpitTargetHandle target,
  ) async {
    final existing = target.capabilityProfile;
    final driver = _platformDriverRegistry.resolve(
      platform: target.platform,
      deviceId: target.deviceId,
    );
    if (existing != null && driver == null) {
      return existing;
    }
    if (driver == null) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedPlatform',
        message: 'No platform driver is available for this target.',
        details: <String, Object?>{'platform': target.platform},
      );
    }
    final described = await driver.describeCapabilities();
    if (existing == null) {
      return described;
    }
    return cockpitMergeTargetCapabilityProfiles(
      primary: existing,
      secondary: described,
    );
  }

  bool _shouldAttemptFlutterRemoteInspect(CockpitTargetHandle target) {
    return target.targetKind == CockpitTargetKind.flutterApp ||
        target.targetKind == CockpitTargetKind.desktopApp;
  }

  Future<CockpitInspectSurfaceResult?> _tryFlutterRemoteInspect({
    required CockpitInspectSurfaceRequest request,
    required CockpitTargetHandle target,
    required CockpitResolvedTargetReference resolved,
    required CockpitCapabilityProfile capabilityProfile,
  }) async {
    if (!_shouldAttemptFlutterRemoteInspect(target)) {
      return null;
    }

    try {
      final inspectResult = await _inspectFlutterSurface(
        CockpitInspectUiRequest(
          app: resolved.app ?? _appFromTarget(target),
          baseUri: resolved.baseUri,
          resultProfile: request.resultProfile,
          snapshotOptions: request.snapshotOptions,
          compareAgainstSnapshotRef: request.compareAgainstSnapshotRef,
        ),
      );
      final mergedProfile = cockpitMergeTargetCapabilityProfiles(
        primary: capabilityProfile,
        secondary: _legacyCapabilityProfile(),
      );
      return CockpitInspectSurfaceResult(
        target: target.copyWith(capabilityProfile: mergedProfile),
        capabilityProfile: mergedProfile,
        surfaceKind: cockpitForegroundSurfaceForTargetProfile(mergedProfile),
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
    } on Object catch (error) {
      if (target.targetKind == CockpitTargetKind.flutterApp ||
          !_isRecoverableFlutterInspectFailure(error)) {
        rethrow;
      }
      return null;
    }
  }

  bool _isRecoverableFlutterInspectFailure(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return true;
    }
    return error is CockpitApplicationServiceException &&
        error.code == 'remoteUnavailable';
  }

  CockpitAppHandle _appFromTarget(CockpitTargetHandle target) {
    return CockpitAppHandle(
      appId: target.targetId,
      mode: CockpitAppMode.automation,
      platform: target.platform,
      deviceId: target.deviceId,
      projectDir: target.projectDir,
      target: target.target,
      baseUrl: target.connection.baseUrl,
      launchedAt: target.launchedAt,
      platformAppId: target.metadata['platformAppId'] as String?,
    );
  }

  List<CockpitInteractiveArtifactDescriptor> _artifactDescriptorsFromExecution(
    CockpitCommandExecution execution,
  ) {
    return execution.result.artifacts
        .map(
          (artifact) => CockpitInteractiveArtifactDescriptor(
            role: artifact.role,
            relativePath: artifact.relativePath,
            sourcePath: execution.artifactSourcePaths[artifact.relativePath],
          ),
        )
        .toList(growable: false);
  }

  CockpitInteractiveSnapshotSummary? _staticSummaryForProfile(
    CockpitInteractiveResultProfile profile,
  ) {
    if (profile.ui == CockpitInteractiveUiLevel.none) {
      return null;
    }
    return CockpitInteractiveSnapshotSummary(
      routeName: null,
      diagnosticLevel: profile.snapshotProfile.jsonValue,
      truncated: false,
      visibleTargetCount: 0,
      targetsWithCockpitIdCount: 0,
      targetsWithTextCount: 0,
      networkEntryCount: 0,
      networkFailureCount: 0,
      runtimeEntryCount: 0,
      runtimeErrorCount: 0,
      rebuildEntryCount: 0,
      totalRebuildCount: 0,
      accessibilityTargetCount: 0,
      accessibilityTraversalCount: 0,
      textPreviews: const <String>[],
    );
  }
}
