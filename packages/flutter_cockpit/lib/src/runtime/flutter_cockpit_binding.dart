import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../model/cockpit_environment.dart';
import '../capture/cockpit_native_capture.dart';
import '../network/cockpit_http_network_observer.dart';
import '../network/cockpit_http_network_observer_configuration.dart';
import '../network/cockpit_network_observer.dart';
import '../recording/cockpit_native_recording.dart';
import '../recording/cockpit_recording_capabilities.dart';
import '../recording/cockpit_recording_kind.dart';
import '../recording/cockpit_recording_layer.dart';
import '../recording/cockpit_recording_request.dart';
import '../recording/cockpit_recording_result.dart';
import '../recording/cockpit_recording_session.dart';
import '../recording/cockpit_recording_state.dart';
import '../session/cockpit_session_controller.dart';
import 'flutter_cockpit_configuration.dart';
import '../model/cockpit_observation.dart';
import 'cockpit_rebuild_tracker.dart';
import 'cockpit_diagnostics_config.dart';
import 'cockpit_runtime_event.dart';
import 'cockpit_runtime_environment.dart';
import 'cockpit_runtime_observer.dart';
import 'cockpit_runtime_observer_configuration.dart';
import 'cockpit_runtime_step_buffer.dart';
import 'cockpit_target_registry.dart';

final class FlutterCockpitBinding {
  FlutterCockpitBinding(FlutterCockpitConfiguration configuration)
    : _configuration = configuration,
      registry =
          configuration.registry ??
          CockpitTargetRegistry(routeName: configuration.initialRouteName),
      nativeCapture =
          configuration.nativeCapture ?? const CockpitNativeCapture(),
      nativeRecording =
          configuration.nativeRecording ?? const CockpitNativeRecording(),
      sessionController =
          configuration.sessionController ??
          CockpitSessionController(
            sessionId:
                'runtime-${DateTime.now().toUtc().microsecondsSinceEpoch}',
            taskId: 'runtime-session',
            platform: defaultTargetPlatform.name,
          ),
      networkObserver =
          configuration.networkObserver ??
          _buildHttpNetworkObserver(configuration.httpNetworkObserver),
      runtimeStepBuffer = CockpitRuntimeStepBuffer(),
      currentRouteName = ValueNotifier<String>(
        _normalizeConfiguredRouteName(configuration.initialRouteName),
      ) {
    rebuildTracker = configuration.diagnostics.enableRebuildTracking
        ? CockpitRebuildTracker(
            routeNameProvider: () => currentRouteName.value,
            maxTrackedEntries:
                configuration.diagnostics.maxTrackedRebuildEntries,
          )
        : null;
    runtimeObserver =
        configuration.runtimeObserver ??
        (configuration.runtimeObserverConfiguration.enabled
            ? configuration.runtimeObserverConfiguration.buildObserver(
                routeNameProvider: () => currentRouteName.value,
                onCriticalEvent: _recordCriticalRuntimeEvent,
              )
            : null);
    _installNetworkOverridesIfEnabled();
    navigatorObserver = _FlutterCockpitNavigatorObserver(_setRouteName);
    registry.routeName = _normalizeConfiguredRouteName(
      configuration.initialRouteName,
    );
  }

  FlutterCockpitConfiguration _configuration;
  CockpitTargetRegistry registry;
  CockpitNativeCapture nativeCapture;
  CockpitNativeRecording nativeRecording;
  CockpitSessionController sessionController;
  CockpitNetworkObserver? networkObserver;
  CockpitRebuildTracker? rebuildTracker;
  CockpitRuntimeObserver? runtimeObserver;
  final CockpitRuntimeStepBuffer runtimeStepBuffer;
  final ValueNotifier<String> currentRouteName;
  late final NavigatorObserver navigatorObserver;
  CockpitRecordingSession? _activeRecordingSession;
  bool _isDisposed = false;
  HttpOverrides? _previousHttpOverrides;
  bool _installedGlobalNetworkOverride = false;
  int _routeNameUpdateGeneration = 0;

  FlutterCockpitConfiguration get configuration => _configuration;

  CockpitRecordingSession? get activeRecordingSession =>
      _activeRecordingSession;

  Future<bool> queryNativeCaptureAvailability() async {
    try {
      return await nativeCapture.queryAvailability();
    } on Object {
      return false;
    }
  }

  Future<CockpitRecordingCapabilities> queryRecordingCapabilities() async {
    try {
      return await nativeRecording.queryCapabilities();
    } on Object catch (error) {
      return CockpitRecordingCapabilities(
        supportsNativeRecording: false,
        preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
        supportedLayers: const <CockpitRecordingLayer>[],
        recordingLimitations: <String>[_recordingProbeFailureMessage(error)],
      );
    }
  }

  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    final session = await nativeRecording.startRecording(request: request);
    _activeRecordingSession = session.state == CockpitRecordingState.recording
        ? session
        : null;
    return session;
  }

  Future<CockpitRecordingResult> stopRecording() async {
    final session = _activeRecordingSession;
    if (session == null) {
      return CockpitRecordingResult(
        state: CockpitRecordingState.failed,
        failureReason: 'recordingNotActive',
      );
    }

    final result = await nativeRecording.stopRecording(session: session);
    _activeRecordingSession = null;
    return result;
  }

  CockpitEnvironment? resolveRuntimeEnvironment({required String platform}) {
    return resolveCockpitRuntimeEnvironment(
      platform: platform,
      configuredFlutterVersion: configuration.flutterVersion,
    );
  }

  void dispose() {
    _isDisposed = true;
    if (_installedGlobalNetworkOverride ||
        identical(HttpOverrides.current, networkObserver)) {
      HttpOverrides.global = _previousHttpOverrides;
      _installedGlobalNetworkOverride = false;
    }
    currentRouteName.dispose();
    _activeRecordingSession = null;
    rebuildTracker?.dispose();
    runtimeObserver?.dispose();
  }

  void updateConfiguration(FlutterCockpitConfiguration nextConfiguration) {
    if (_isDisposed) {
      return;
    }

    final previousConfiguration = _configuration;
    final previousRuntimeObserverConfig =
        previousConfiguration.runtimeObserverConfiguration;
    final previousDiagnostics = previousConfiguration.diagnostics;

    final previousInitialRouteName = _normalizeConfiguredRouteName(
      previousConfiguration.initialRouteName,
    );
    final nextInitialRouteName = _normalizeConfiguredRouteName(
      nextConfiguration.initialRouteName,
    );
    if (currentRouteName.value == previousInitialRouteName &&
        nextInitialRouteName != currentRouteName.value) {
      _applyRouteName(nextInitialRouteName);
    }

    _reconfigureNetworkObserver(nextConfiguration);
    _reconfigureRuntimeObserver(
      previousConfig: previousRuntimeObserverConfig,
      nextConfiguration: nextConfiguration,
    );
    _reconfigureRebuildTracker(
      previousDiagnostics: previousDiagnostics,
      nextDiagnostics: nextConfiguration.diagnostics,
    );
    _reconfigureRuntimeReferences(nextConfiguration);

    _configuration = nextConfiguration.copyWith(
      registry: registry,
      nativeCapture: nativeCapture,
      nativeRecording: nativeRecording,
      sessionController: sessionController,
      networkObserver: networkObserver,
      runtimeObserver: runtimeObserver,
    );
  }

  void _reconfigureRuntimeReferences(
    FlutterCockpitConfiguration nextConfiguration,
  ) {
    final nextRegistry = nextConfiguration.registry;
    if (nextRegistry != null && !identical(nextRegistry, registry)) {
      nextRegistry.routeName = currentRouteName.value;
      registry = nextRegistry;
    } else {
      registry.routeName = currentRouteName.value;
    }

    final nextSessionController = nextConfiguration.sessionController;
    if (nextSessionController != null &&
        !identical(nextSessionController, sessionController)) {
      sessionController = nextSessionController;
    }

    final nextNativeCapture = nextConfiguration.nativeCapture;
    if (nextNativeCapture != null &&
        !identical(nextNativeCapture, nativeCapture)) {
      nativeCapture = nextNativeCapture;
    }

    final nextNativeRecording = nextConfiguration.nativeRecording;
    if (nextNativeRecording != null &&
        !identical(nextNativeRecording, nativeRecording)) {
      nativeRecording = nextNativeRecording;
      _activeRecordingSession = null;
    }
  }

  void _installNetworkOverridesIfEnabled() {
    final observer = networkObserver;
    if (observer is! CockpitHttpNetworkObserver) {
      return;
    }
    _previousHttpOverrides = HttpOverrides.current;
    if (!observer.hasAttachedParentOverrides) {
      observer.attachParentOverrides(_previousHttpOverrides);
    }
    HttpOverrides.global = observer;
    _installedGlobalNetworkOverride = true;
  }

  void _reconfigureNetworkObserver(
    FlutterCockpitConfiguration nextConfiguration,
  ) {
    final nextObserver =
        nextConfiguration.networkObserver ??
        _buildHttpNetworkObserver(nextConfiguration.httpNetworkObserver);
    if (identical(networkObserver, nextObserver)) {
      return;
    }

    if (_installedGlobalNetworkOverride ||
        identical(HttpOverrides.current, networkObserver)) {
      HttpOverrides.global = _previousHttpOverrides;
      _installedGlobalNetworkOverride = false;
    }

    networkObserver = nextObserver;
    _installNetworkOverridesIfEnabled();
  }

  void _reconfigureRuntimeObserver({
    required CockpitRuntimeObserverConfiguration previousConfig,
    required FlutterCockpitConfiguration nextConfiguration,
  }) {
    if (nextConfiguration.runtimeObserver != null) {
      if (!identical(runtimeObserver, nextConfiguration.runtimeObserver)) {
        runtimeObserver?.dispose();
      }
      runtimeObserver = nextConfiguration.runtimeObserver;
      return;
    }

    final nextConfig = nextConfiguration.runtimeObserverConfiguration;
    if (previousConfig == nextConfig) {
      return;
    }

    runtimeObserver?.dispose();
    runtimeObserver = nextConfig.enabled
        ? nextConfig.buildObserver(
            routeNameProvider: () => currentRouteName.value,
            onCriticalEvent: _recordCriticalRuntimeEvent,
          )
        : null;
  }

  void _reconfigureRebuildTracker({
    required CockpitDiagnosticsConfig previousDiagnostics,
    required CockpitDiagnosticsConfig nextDiagnostics,
  }) {
    final changed =
        previousDiagnostics.enableRebuildTracking !=
            nextDiagnostics.enableRebuildTracking ||
        previousDiagnostics.maxTrackedRebuildEntries !=
            nextDiagnostics.maxTrackedRebuildEntries;
    if (!changed) {
      return;
    }

    rebuildTracker?.dispose();
    rebuildTracker = nextDiagnostics.enableRebuildTracking
        ? CockpitRebuildTracker(
            routeNameProvider: () => currentRouteName.value,
            maxTrackedEntries: nextDiagnostics.maxTrackedRebuildEntries,
          )
        : null;
  }

  void _setRouteName(Route<dynamic>? route) {
    if (_isDisposed) {
      return;
    }
    final nextRouteName = _normalizeObservedRouteName(route?.settings.name);
    if (currentRouteName.value == nextRouteName &&
        registry.routeName == nextRouteName) {
      return;
    }

    final generation = ++_routeNameUpdateGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || generation != _routeNameUpdateGeneration) {
        return;
      }
      _applyRouteName(nextRouteName);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _applyRouteName(String routeName) {
    if (_isDisposed) {
      return;
    }
    currentRouteName.value = routeName;
    registry.routeName = routeName;
  }

  void setCurrentRouteName(String routeName) {
    if (_isDisposed) {
      return;
    }
    _routeNameUpdateGeneration++;
    _applyRouteName(_normalizeExplicitRouteName(routeName));
  }

  String _normalizeObservedRouteName(String? routeName) {
    final initialRouteName = _normalizeConfiguredRouteName(
      configuration.initialRouteName,
    );
    if (routeName == null) {
      return initialRouteName;
    }
    final trimmedRouteName = routeName.trim();
    if (trimmedRouteName.isEmpty) {
      return initialRouteName;
    }
    return trimmedRouteName == '/' && initialRouteName != '/'
        ? initialRouteName
        : trimmedRouteName;
  }

  String _normalizeExplicitRouteName(String routeName) {
    final trimmedRouteName = routeName.trim();
    return trimmedRouteName.isEmpty
        ? _normalizeConfiguredRouteName(configuration.initialRouteName)
        : trimmedRouteName;
  }

  void _recordCriticalRuntimeEvent(CockpitRuntimeEvent event) {
    final observation = CockpitObservation(
      routeName: event.routeName,
      phase: CockpitObservationPhase.failure,
      interactiveElements: const <String>[],
    );
    final actionArgs = <String, Object?>{
      'eventId': event.eventId,
      'kind': event.kind.jsonValue,
      'severity': event.severity.jsonValue,
      'message': event.message,
      'routeName': event.routeName,
      'source': event.source,
      'details': event.details,
      'stackTracePreview': event.stackTracePreview,
      'stackTraceTruncated': event.stackTraceTruncated,
      'recordedAt': event.recordedAt.toUtc().toIso8601String(),
    };
    runtimeStepBuffer.recordStep(
      actionType: 'runtime_event',
      actionArgs: actionArgs,
      observation: observation,
    );
    try {
      sessionController.recordStep(
        actionType: 'runtime_event',
        actionArgs: actionArgs,
        observation: observation,
      );
    } on StateError {
      // Runtime observation must never crash the app after a session has closed.
    }
  }
}

String _recordingProbeFailureMessage(Object error) {
  return switch (error) {
    MissingPluginException(:final message?) =>
      message.isEmpty ? 'Native recording plugin is unavailable.' : message,
    MissingPluginException() => 'Native recording plugin is unavailable.',
    PlatformException(:final message?, :final code) =>
      message.isNotEmpty ? message : code,
    StateError(:final message) => message,
    _ => '$error',
  };
}

CockpitHttpNetworkObserver? _buildHttpNetworkObserver(
  CockpitHttpNetworkObserverConfiguration? configuration,
) {
  if (configuration == null) {
    return null;
  }
  return CockpitHttpNetworkObserver(
    maxRetainedEntries: configuration.maxRetainedEntries,
    maxHeaderCount: configuration.maxHeaderCount,
    maxHeaderValueLength: configuration.maxHeaderValueLength,
    maxBodyBytes: configuration.maxBodyBytes,
    captureHeaders: configuration.captureHeaders,
    captureBodies: configuration.captureBodies,
  );
}

String _normalizeConfiguredRouteName(String routeName) {
  final trimmedRouteName = routeName.trim();
  return trimmedRouteName.isEmpty ? '/' : trimmedRouteName;
}

final class _FlutterCockpitNavigatorObserver extends NavigatorObserver {
  _FlutterCockpitNavigatorObserver(this._onRouteChanged);

  final void Function(Route<dynamic>? route) _onRouteChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRouteChanged(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRouteChanged(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onRouteChanged(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onRouteChanged(newRoute);
  }
}
