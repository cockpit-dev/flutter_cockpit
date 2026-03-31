import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../capture/cockpit_capture_kind.dart';
import '../capture/cockpit_capture_profile.dart';
import '../capture/cockpit_capture_result.dart';
import '../control/cockpit_screenshot_request.dart';
import '../executor/in_app_cockpit_command_executor.dart';
import '../gesture/cockpit_gesture_action.dart';
import '../remote/cockpit_remote_session_server.dart';
import '../remote/cockpit_remote_session_status.dart';
import '../recording/cockpit_recording_capabilities.dart';
import '../recording/cockpit_recording_request.dart';
import '../recording/cockpit_recording_result.dart';
import '../recording/cockpit_recording_session.dart';
import 'flutter_cockpit.dart';
import 'cockpit_tap_feedback_overlay.dart';
import 'cockpit_capabilities.dart';
import 'cockpit_runtime_query.dart';
import 'cockpit_scroll_step_result.dart';
import 'cockpit_snapshot.dart';
import 'cockpit_snapshot_options.dart';
import 'cockpit_surface.dart';
import 'cockpit_ui_idle_waiter.dart';

final class FlutterCockpitRoot extends StatefulWidget {
  const FlutterCockpitRoot({required this.child, super.key});

  final Widget child;

  @override
  State<FlutterCockpitRoot> createState() => FlutterCockpitRootState();
}

final class FlutterCockpitRootState extends State<FlutterCockpitRoot> {
  final GlobalKey<CockpitSurfaceState> _surfaceKey =
      GlobalKey<CockpitSurfaceState>();
  CockpitRemoteSessionServer? _remoteSessionServer;
  Future<void>? _remoteSessionStartFuture;
  CockpitTapFeedbackController? _tapFeedbackController;

  @override
  void initState() {
    super.initState();
    _syncTapFeedbackController();
    final configuration = FlutterCockpit.binding.configuration.remoteSession;
    if (configuration != null &&
        configuration.enabled &&
        configuration.autoStart) {
      _remoteSessionStartFuture = _startRemoteSessionIfEnabled();
    }
  }

  @override
  void didUpdateWidget(covariant FlutterCockpitRoot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTapFeedbackController();
  }

  CockpitSnapshot snapshot({
    CockpitSnapshotOptions options = const CockpitSnapshotOptions(),
  }) {
    final surfaceState = _surfaceKey.currentState;
    if (surfaceState == null) {
      throw StateError('FlutterCockpitRoot is not mounted.');
    }
    final snapshot = surfaceState.snapshot(options: options);
    final networkObserver = FlutterCockpit.binding.networkObserver;
    final runtimeObserver = FlutterCockpit.binding.runtimeObserver;
    return snapshot.copyWith(
      network: !options.includeNetworkActivity || networkObserver == null
          ? snapshot.network
          : networkObserver.snapshot(
              maxEntries: options.maxNetworkEntries,
              query: options.networkQuery,
            ),
      runtime: !options.includeRuntimeActivity || runtimeObserver == null
          ? snapshot.runtime
          : runtimeObserver.snapshot(
              maxEntries: options.maxRuntimeEntries,
              query: options.runtimeQuery,
            ),
    );
  }

  Future<bool> waitForUiIdle({
    Duration? quietWindow,
    Duration? timeout,
    bool? includeNetworkIdle,
  }) {
    final interactionPolicy =
        FlutterCockpit.binding.configuration.interactionPolicy;
    return waitForCockpitUiIdle(
      quietWindow: quietWindow ?? interactionPolicy.uiIdleQuietWindow,
      timeout: timeout ?? interactionPolicy.uiIdleTimeout,
      waitTick: (duration) => Future<void>.delayed(duration),
      waitForNetworkIdle: FlutterCockpit.binding.networkObserver?.waitForIdle,
      includeNetworkIdle: includeNetworkIdle ??
          interactionPolicy.waitForNetworkIdleDuringAcceptanceCapture,
    );
  }

  Future<CockpitCaptureResult> captureScreenshot(
    CockpitScreenshotRequest request, {
    CockpitCaptureProfile? profile,
    bool allowFallback = true,
  }) async {
    final effectiveProfile = profile ?? _defaultProfileFor(request);
    final effectiveRequest = request.snapshotOptions == null
        ? request.copyWith(
            snapshotOptions: _defaultSnapshotOptionsFor(request.reason),
          )
        : request;
    final surfaceState = _surfaceKey.currentState;
    if (surfaceState == null) {
      throw StateError('FlutterCockpitRoot is not mounted.');
    }

    if (effectiveRequest.reason == CockpitScreenshotReason.acceptance) {
      await waitForUiIdle();
    }

    final snapshotData = effectiveRequest.includeSnapshot
        ? surfaceState.snapshot(
            options: effectiveRequest.snapshotOptions ??
                _defaultSnapshotOptionsFor(effectiveRequest.reason),
          )
        : null;

    if (effectiveProfile == CockpitCaptureProfile.acceptance ||
        effectiveProfile == CockpitCaptureProfile.nativePreferred) {
      try {
        final screenshot = await FlutterCockpit.binding.nativeCapture.capture(
          request: effectiveRequest,
          profile: effectiveProfile,
          snapshot: snapshotData,
        );
        return CockpitCaptureResult(
          screenshot: screenshot,
          requestedProfile: effectiveProfile,
          resolvedCaptureKind: CockpitCaptureKind.nativeAcceptance,
        );
      } on MissingPluginException catch (error) {
        if (!allowFallback) {
          rethrow;
        }

        final screenshot = await surfaceState.captureScreenshot(
          effectiveRequest,
        );
        return CockpitCaptureResult(
          screenshot: screenshot,
          requestedProfile: effectiveProfile,
          resolvedCaptureKind: CockpitCaptureKind.flutterView,
          usedFallback: true,
          degradationReason: error.message,
        );
      } on PlatformException catch (error) {
        if (!allowFallback) {
          rethrow;
        }

        final screenshot = await surfaceState.captureScreenshot(
          effectiveRequest,
        );
        return CockpitCaptureResult(
          screenshot: screenshot,
          requestedProfile: effectiveProfile,
          resolvedCaptureKind: CockpitCaptureKind.flutterView,
          usedFallback: true,
          degradationReason: error.message ?? error.code,
        );
      }
    }

    final screenshot = await surfaceState.captureScreenshot(effectiveRequest);
    return CockpitCaptureResult(
      screenshot: screenshot,
      requestedProfile: effectiveProfile,
      resolvedCaptureKind: CockpitCaptureKind.flutterView,
    );
  }

  Future<CockpitRecordingCapabilities> queryRecordingCapabilities() {
    return FlutterCockpit.binding.queryRecordingCapabilities();
  }

  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    return FlutterCockpit.binding.startRecording(request);
  }

  Future<CockpitRecordingResult> stopRecording() {
    return FlutterCockpit.binding.stopRecording();
  }

  Future<void> performGesture(CockpitGestureAction action) {
    final surfaceState = _surfaceKey.currentState;
    if (surfaceState == null) {
      throw StateError('FlutterCockpitRoot is not mounted.');
    }
    return surfaceState.performGesture(action);
  }

  Uri? get remoteSessionBaseUri => _remoteSessionServer?.baseUri;

  Future<Uri?> waitForRemoteSession() async {
    await _ensureRemoteSessionStarted();
    return _remoteSessionServer?.baseUri;
  }

  Future<CockpitRemoteSessionStatus> remoteSessionStatus() {
    return _withRemoteSessionStarted(_buildRemoteSessionStatus);
  }

  @override
  void dispose() {
    unawaited(_remoteSessionServer?.close());
    _tapFeedbackController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final binding = FlutterCockpit.binding;
    return ValueListenableBuilder<String>(
      valueListenable: binding.currentRouteName,
      builder: (context, routeName, child) {
        final surface = CockpitSurface(
          key: _surfaceKey,
          routeName: routeName,
          registry: binding.registry,
          gestureDelay: binding.configuration.gestureDelay,
          discoveryPolicy: binding.configuration.discoveryPolicy,
          rebuildTracker: binding.rebuildTracker,
          tapFeedbackController: _tapFeedbackController,
          child: child ?? const SizedBox.shrink(),
        );
        final tapFeedbackController = _tapFeedbackController;
        if (tapFeedbackController == null) {
          return surface;
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            surface,
            Positioned.fill(
              child: CockpitTapFeedbackOverlay(
                controller: tapFeedbackController,
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }

  void _syncTapFeedbackController() {
    final shouldEnable = kDebugMode &&
        FlutterCockpit.binding.configuration.diagnostics.enableTapFeedback;
    if (shouldEnable) {
      _tapFeedbackController ??= CockpitTapFeedbackController();
      return;
    }
    _tapFeedbackController?.dispose();
    _tapFeedbackController = null;
  }

  CockpitCaptureProfile _defaultProfileFor(CockpitScreenshotRequest request) {
    return request.reason == CockpitScreenshotReason.acceptance
        ? CockpitCaptureProfile.acceptance
        : CockpitCaptureProfile.diagnostic;
  }

  CockpitSnapshotOptions _defaultSnapshotOptionsFor(
    CockpitScreenshotReason reason,
  ) {
    return switch (reason) {
      CockpitScreenshotReason.assertionFailure =>
        const CockpitSnapshotOptions.investigate(),
      CockpitScreenshotReason.baseline =>
        const CockpitSnapshotOptions.baseline(),
      CockpitScreenshotReason.acceptance =>
        const CockpitSnapshotOptions.investigate(),
      CockpitScreenshotReason.beforeAction ||
      CockpitScreenshotReason.afterAction =>
        const CockpitSnapshotOptions.live(),
    };
  }

  Future<void> _startRemoteSessionIfEnabled() async {
    final configuration = FlutterCockpit.binding.configuration.remoteSession;
    if (configuration == null || !configuration.enabled) {
      return;
    }
    if (_remoteSessionServer != null) {
      return;
    }

    final executor = InAppCockpitCommandExecutor(
      registry: FlutterCockpit.binding.registry,
      captureHandler: captureScreenshot,
      snapshotProvider: snapshot,
      scrollStepHandler: ({
        required reverse,
        required viewportFraction,
        scrollableKey,
        targetLocator,
        scrollableLocator,
        required duration,
        required gestureProfile,
        required continuous,
        required postScrollEnsureVisible,
      }) {
        final surfaceState = _surfaceKey.currentState;
        if (surfaceState == null) {
          return Future<CockpitScrollStepResult>.value(
            const CockpitScrollStepResult(didScroll: false),
          );
        }
        return surfaceState.scrollByViewport(
          reverse: reverse,
          viewportFraction: viewportFraction,
          scrollableKey: scrollableKey,
          targetLocator: targetLocator,
          scrollableLocator: scrollableLocator,
          duration: duration,
          gestureProfile: gestureProfile,
          continuous: continuous,
          postScrollEnsureVisible: postScrollEnsureVisible,
        );
      },
      ensureVisibleHandler: ({
        required locator,
        required duration,
        required alignment,
        required padding,
      }) {
        final surfaceState = _surfaceKey.currentState;
        if (surfaceState == null) {
          return Future<bool>.value(false);
        }
        return surfaceState.ensureLocatorVisible(
          locator,
          duration: duration,
          alignment: alignment,
          padding: padding,
        );
      },
      gestureHandler: (action) {
        final surfaceState = _surfaceKey.currentState;
        if (surfaceState == null) {
          return Future<void>.error(
            StateError('FlutterCockpitRoot surface is not mounted.'),
          );
        }
        return surfaceState.performGesture(action);
      },
      clearNetworkActivityHandler:
          FlutterCockpit.binding.networkObserver == null
              ? null
              : () {
                  FlutterCockpit.binding.networkObserver?.clear();
                },
      waitForNetworkIdleHandler: FlutterCockpit.binding.networkObserver == null
          ? null
          : ({required quietWindow, required timeout}) {
              return FlutterCockpit.binding.networkObserver!.waitForIdle(
                quietWindow: quietWindow,
                timeout: timeout,
              );
            },
      waitTickHandler: FlutterCockpit.binding.configuration.gestureDelay,
      interactionPolicy: FlutterCockpit.binding.configuration.interactionPolicy,
      isRecordingActive: () =>
          FlutterCockpit.binding.activeRecordingSession != null,
      backNavigationHandler: () async {
        final navigator = FlutterCockpit.binding.navigatorObserver.navigator;
        return navigator?.maybePop() ?? false;
      },
      platform: defaultTargetPlatform.name,
      transportType: 'remoteHttp',
    );
    final server = CockpitRemoteSessionServer(
      configuration: configuration,
      statusProvider: _buildRemoteSessionStatus,
      snapshotProvider: ({required options}) => snapshot(options: options),
      commandExecutor: executor.executeWithArtifacts,
      runtimeStepDrainer: ({required clear}) {
        return FlutterCockpit.drainRecordedSteps(clear: clear);
      },
      startRecording: startRecording,
      stopRecording: stopRecording,
    );
    await server.start();
    _remoteSessionServer = server;
  }

  Future<void> _ensureRemoteSessionStarted() {
    final configuration = FlutterCockpit.binding.configuration.remoteSession;
    if (configuration == null || !configuration.enabled) {
      return Future<void>.value();
    }

    return _remoteSessionStartFuture ??= _startRemoteSessionIfEnabled();
  }

  Future<T> _withRemoteSessionStarted<T>(Future<T> Function() action) async {
    await _ensureRemoteSessionStarted();
    return action();
  }

  Future<CockpitRemoteSessionStatus> _buildRemoteSessionStatus() async {
    final executor = InAppCockpitCommandExecutor(
      registry: FlutterCockpit.binding.registry,
      captureHandler: captureScreenshot,
      snapshotProvider: snapshot,
      scrollStepHandler: ({
        required reverse,
        required viewportFraction,
        scrollableKey,
        targetLocator,
        scrollableLocator,
        required duration,
        required gestureProfile,
        required continuous,
        required postScrollEnsureVisible,
      }) {
        final surfaceState = _surfaceKey.currentState;
        if (surfaceState == null) {
          return Future<CockpitScrollStepResult>.value(
            const CockpitScrollStepResult(didScroll: false),
          );
        }
        return surfaceState.scrollByViewport(
          reverse: reverse,
          viewportFraction: viewportFraction,
          scrollableKey: scrollableKey,
          targetLocator: targetLocator,
          scrollableLocator: scrollableLocator,
          duration: duration,
          gestureProfile: gestureProfile,
          continuous: continuous,
          postScrollEnsureVisible: postScrollEnsureVisible,
        );
      },
      ensureVisibleHandler: ({
        required locator,
        required duration,
        required alignment,
        required padding,
      }) {
        final surfaceState = _surfaceKey.currentState;
        if (surfaceState == null) {
          return Future<bool>.value(false);
        }
        return surfaceState.ensureLocatorVisible(
          locator,
          duration: duration,
          alignment: alignment,
          padding: padding,
        );
      },
      gestureHandler: (action) {
        final surfaceState = _surfaceKey.currentState;
        if (surfaceState == null) {
          return Future<void>.error(
            StateError('FlutterCockpitRoot surface is not mounted.'),
          );
        }
        return surfaceState.performGesture(action);
      },
      waitTickHandler: FlutterCockpit.binding.configuration.gestureDelay,
      interactionPolicy: FlutterCockpit.binding.configuration.interactionPolicy,
      isRecordingActive: () =>
          FlutterCockpit.binding.activeRecordingSession != null,
      platform: defaultTargetPlatform.name,
      transportType: 'remoteHttp',
    );
    final baseCapabilities = await executor.describeCapabilities();
    final supportsNativeCapture =
        await FlutterCockpit.binding.queryNativeCaptureAvailability();
    return CockpitRemoteSessionStatus(
      sessionId:
          'cockpit-${defaultTargetPlatform.name}-${remoteSessionBaseUri?.port ?? 0}',
      platform: defaultTargetPlatform.name,
      transportType: 'remoteHttp',
      currentRouteName: FlutterCockpit.binding.currentRouteName.value,
      capabilities: CockpitCapabilities(
        platform: baseCapabilities.platform,
        transportType: baseCapabilities.transportType,
        supportsInAppControl: baseCapabilities.supportsInAppControl,
        supportsFlutterViewCapture: baseCapabilities.supportsFlutterViewCapture,
        supportsNativeScreenCapture: supportsNativeCapture,
        supportsHostAutomation: baseCapabilities.supportsHostAutomation,
        supportedCommands: baseCapabilities.supportedCommands,
        supportedLocatorStrategies: baseCapabilities.supportedLocatorStrategies,
      ),
      recordingCapabilities: await queryRecordingCapabilities(),
      snapshot: snapshot(
        options: const CockpitSnapshotOptions(
          profile: CockpitSnapshotProfile.live,
          includeRuntimeActivity: true,
          maxRuntimeEntries: 4,
          runtimeQuery: CockpitRuntimeQuery(onlyErrors: true),
        ),
      ),
      environment: FlutterCockpit.binding.resolveRuntimeEnvironment(
        platform: defaultTargetPlatform.name,
      ),
      activeRecording: FlutterCockpit.binding.activeRecordingSession,
    );
  }
}
