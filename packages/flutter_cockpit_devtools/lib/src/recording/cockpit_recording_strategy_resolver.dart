import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_recording_adapter.dart';
import '../platform/ios/cockpit_ios_device_connection.dart';
import '../remote/cockpit_remote_recording_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_adb_recording_adapter.dart';
import 'cockpit_host_recording_adapter.dart';
import 'cockpit_linux_recording_adapter.dart';
import 'cockpit_macos_recording_adapter.dart';
import 'cockpit_recording_strategy_resolution.dart';
import 'cockpit_simctl_recording_adapter.dart';
import 'cockpit_windows_recording_adapter.dart';

typedef CockpitRemoteRecordingAdapterFactory = CockpitRecordingAdapter Function(
    CockpitRemoteSessionClient client);
typedef CockpitAdbRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String deviceId);
typedef CockpitSimctlRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String deviceId);
typedef CockpitMacosRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String appId);
typedef CockpitWindowsRecordingAdapterFactory = CockpitRecordingAdapter
    Function(String appId);
typedef CockpitLinuxRecordingAdapterFactory = CockpitRecordingAdapter Function(
    String appId);

final class CockpitRecordingStrategyResolver {
  const CockpitRecordingStrategyResolver({
    this.remoteAdapterFactory = _defaultRemoteAdapterFactory,
    this.adbAdapterFactory = _defaultAdbAdapterFactory,
    this.simctlAdapterFactory = _defaultSimctlAdapterFactory,
    this.macosAdapterFactory = _defaultMacosAdapterFactory,
    this.windowsAdapterFactory = _defaultWindowsAdapterFactory,
    this.linuxAdapterFactory = _defaultLinuxAdapterFactory,
  });

  final CockpitRemoteRecordingAdapterFactory remoteAdapterFactory;
  final CockpitAdbRecordingAdapterFactory adbAdapterFactory;
  final CockpitSimctlRecordingAdapterFactory simctlAdapterFactory;
  final CockpitMacosRecordingAdapterFactory macosAdapterFactory;
  final CockpitWindowsRecordingAdapterFactory windowsAdapterFactory;
  final CockpitLinuxRecordingAdapterFactory linuxAdapterFactory;

  CockpitRecordingAdapter? resolve({
    required String platform,
    required CockpitRecordingRequest? recording,
    required CockpitRemoteSessionClient client,
    CockpitRemoteSessionHandle? sessionHandle,
    String? androidDeviceId,
    String? iosDeviceId,
    String? platformAppId,
    bool preferActiveHostSession = false,
  }) {
    return resolveDetailed(
      platform: platform,
      recording: recording,
      client: client,
      sessionHandle: sessionHandle,
      androidDeviceId: androidDeviceId,
      iosDeviceId: iosDeviceId,
      platformAppId: platformAppId,
      preferActiveHostSession: preferActiveHostSession,
    )?.adapter;
  }

  CockpitRecordingStrategyResolution? resolveDetailed({
    required String platform,
    required CockpitRecordingRequest? recording,
    required CockpitRemoteSessionClient client,
    CockpitRemoteSessionHandle? sessionHandle,
    String? androidDeviceId,
    String? iosDeviceId,
    String? platformAppId,
    bool preferActiveHostSession = false,
  }) {
    if (recording == null) {
      return null;
    }

    final normalizedPlatform = platform.trim().toLowerCase();
    final candidates = _orderedCandidates(
      platform: normalizedPlatform,
      mode: recording.mode,
      client: client,
      sessionHandle: sessionHandle,
      androidDeviceId: androidDeviceId,
      iosDeviceId: iosDeviceId,
      platformAppId: platformAppId,
      preferActiveHostSession: preferActiveHostSession,
    );
    final desiredLayer = recording.layer ??
        _preferredLayerForMode(normalizedPlatform, recording.mode);

    final preferredActiveSessionCandidate =
        _preferredActiveSessionCandidate(candidates, preferActiveHostSession);
    if (preferredActiveSessionCandidate != null) {
      final effectiveLayer = preferredActiveSessionCandidate.layer;
      final fallbackUsed =
          desiredLayer != null && effectiveLayer != desiredLayer;
      return _buildResolution(
        candidate: preferredActiveSessionCandidate,
        request: recording,
        effectiveLayer: effectiveLayer,
        fallbackUsed: fallbackUsed,
        fallbackReason: fallbackUsed
            ? 'An active host recording session is already running. '
                'Reusing ${effectiveLayer.jsonValue} to stop the active host recording.'
            : null,
      );
    }

    if (desiredLayer != null) {
      for (final candidate in candidates) {
        if (candidate.layer == desiredLayer) {
          return _buildResolution(
            candidate: candidate,
            request: recording,
            effectiveLayer: desiredLayer,
          );
        }
      }

      if (!recording.allowsFallback) {
        return CockpitRecordingStrategyResolution(
          implementation: 'unavailable',
          requestedMode: recording.mode,
          requestedLayer: recording.layer,
          fallbackUsed: false,
          unsupportedReason:
              'Recording layer ${desiredLayer.jsonValue} is unavailable on $normalizedPlatform.',
        );
      }
    } else if (!recording.allowsFallback) {
      return CockpitRecordingStrategyResolution(
        implementation: 'unavailable',
        requestedMode: recording.mode,
        requestedLayer: recording.layer,
        fallbackUsed: false,
        unsupportedReason:
            'Recording mode ${recording.mode.jsonValue} is unavailable on $normalizedPlatform.',
      );
    }

    if (candidates.isEmpty) {
      return CockpitRecordingStrategyResolution(
        implementation: 'unavailable',
        requestedMode: recording.mode,
        requestedLayer: recording.layer,
        fallbackUsed: false,
        unsupportedReason:
            'No recording strategy is available for $normalizedPlatform.',
      );
    }

    final fallbackCandidate = desiredLayer == null
        ? candidates.first
        : _closestLayerCandidate(candidates, desiredLayer);
    return _buildResolution(
      candidate: fallbackCandidate,
      request: recording,
      effectiveLayer: fallbackCandidate.layer,
      fallbackUsed: true,
      fallbackReason: desiredLayer == null
          ? 'Recording mode ${recording.mode.jsonValue} is unavailable on $normalizedPlatform. Falling back to ${fallbackCandidate.layer.jsonValue}.'
          : 'Recording layer ${desiredLayer.jsonValue} is unavailable on $normalizedPlatform. Falling back to ${fallbackCandidate.layer.jsonValue}.',
    );
  }

  _RecordingCandidate? _preferredActiveSessionCandidate(
    List<_RecordingCandidate> candidates,
    bool preferActiveHostSession,
  ) {
    if (!preferActiveHostSession || candidates.isEmpty) {
      return null;
    }
    final candidate = candidates.first;
    final sessionKey = candidate.sessionKey;
    if (sessionKey == null ||
        !cockpitHasActiveHostRecordingSession(sessionKey)) {
      return null;
    }
    return candidate;
  }

  CockpitRecordingStrategyResolution _buildResolution({
    required _RecordingCandidate candidate,
    required CockpitRecordingRequest request,
    required CockpitRecordingLayer effectiveLayer,
    bool fallbackUsed = false,
    String? fallbackReason,
  }) {
    return CockpitRecordingStrategyResolution(
      implementation: candidate.implementation,
      adapter: _PolicyAwareRecordingAdapter(
        delegate: candidate.factory(),
        requestedMode: request.mode,
        requestedLayer: request.layer,
        effectiveLayer: effectiveLayer,
        fallbackUsed: fallbackUsed,
        fallbackReason: fallbackReason,
      ),
      requestedMode: request.mode,
      requestedLayer: request.layer,
      effectiveLayer: effectiveLayer,
      fallbackUsed: fallbackUsed,
      fallbackReason: fallbackReason,
    );
  }

  List<_RecordingCandidate> _orderedCandidates({
    required String platform,
    required CockpitRecordingMode mode,
    required CockpitRemoteSessionClient client,
    required CockpitRemoteSessionHandle? sessionHandle,
    required String? androidDeviceId,
    required String? iosDeviceId,
    required String? platformAppId,
    required bool preferActiveHostSession,
  }) {
    final remote = _RecordingCandidate(
      implementation: 'remote',
      layer: _remoteLayerForPlatform(platform),
      factory: () => remoteAdapterFactory(client),
    );
    switch (platform) {
      case 'android':
        return _mobileCandidates(
          mode: mode,
          remote: remote,
          host: (androidDeviceId == null || androidDeviceId.isEmpty)
              ? null
              : _RecordingCandidate(
                  implementation: 'adb',
                  layer: CockpitRecordingLayer.system,
                  factory: () => adbAdapterFactory(androidDeviceId),
                  sessionKey: 'adb:$androidDeviceId',
                ),
          activeHostSession: androidDeviceId != null &&
              androidDeviceId.isNotEmpty &&
              cockpitHasActiveAdbRecordingSession(androidDeviceId),
          preferActiveHostSession: preferActiveHostSession,
        );
      case 'ios':
        final simulatorDeviceId = (iosDeviceId == null ||
                iosDeviceId.isEmpty ||
                !cockpitLooksLikeIosSimulatorDeviceId(iosDeviceId))
            ? null
            : iosDeviceId;
        return _mobileCandidates(
          mode: mode,
          remote: remote,
          host: (simulatorDeviceId == null || simulatorDeviceId.isEmpty)
              ? null
              : _RecordingCandidate(
                  implementation: 'simctl',
                  layer: CockpitRecordingLayer.system,
                  factory: () => simctlAdapterFactory(simulatorDeviceId),
                ),
          activeHostSession: simulatorDeviceId != null &&
              simulatorDeviceId.isNotEmpty &&
              cockpitHasActiveSimctlRecordingSession(simulatorDeviceId),
          preferActiveHostSession: preferActiveHostSession,
        );
      case 'macos':
        return _desktopCandidates(
          mode: mode,
          remote: remote,
          host: _desktopHostCandidate(
            platform: platform,
            appId: platformAppId ?? sessionHandle?.appId,
          ),
          preferActiveHostSession: preferActiveHostSession,
        );
      case 'windows':
        return _desktopCandidates(
          mode: mode,
          remote: remote,
          host: _desktopHostCandidate(
            platform: platform,
            appId: platformAppId ?? sessionHandle?.appId,
          ),
          preferActiveHostSession: preferActiveHostSession,
        );
      case 'linux':
        return _desktopCandidates(
          mode: mode,
          remote: remote,
          host: _desktopHostCandidate(
            platform: platform,
            appId: platformAppId ?? sessionHandle?.appId,
          ),
          preferActiveHostSession: preferActiveHostSession,
        );
      case 'web':
        return <_RecordingCandidate>[remote];
      default:
        return <_RecordingCandidate>[remote];
    }
  }

  _RecordingCandidate? _desktopHostCandidate({
    required String platform,
    required String? appId,
  }) {
    if (appId == null || appId.isEmpty) {
      return null;
    }
    final hostCandidate = switch (platform) {
      'macos' => _RecordingCandidate(
          implementation: 'macosHost',
          layer: CockpitRecordingLayer.hostScreen,
          factory: () => macosAdapterFactory(appId),
          sessionKey: 'macos:$appId',
        ),
      'windows' => _RecordingCandidate(
          implementation: 'windowsHost',
          layer: CockpitRecordingLayer.hostScreen,
          factory: () => windowsAdapterFactory(appId),
          sessionKey: 'windows:$appId',
        ),
      'linux' => _RecordingCandidate(
          implementation: 'linuxHost',
          layer: CockpitRecordingLayer.hostScreen,
          factory: () => linuxAdapterFactory(appId),
          sessionKey: 'linux:$appId',
        ),
      _ => null,
    };
    return hostCandidate;
  }

  List<_RecordingCandidate> _mobileCandidates({
    required CockpitRecordingMode mode,
    required _RecordingCandidate remote,
    required _RecordingCandidate? host,
    required bool activeHostSession,
    required bool preferActiveHostSession,
  }) {
    final ordered = <_RecordingCandidate>[];
    if (activeHostSession && host != null) {
      ordered.add(host);
      ordered.add(remote);
      return ordered;
    }
    if (preferActiveHostSession) {
      ordered.add(remote);
      if (host != null) {
        ordered.add(host);
      }
      return ordered;
    }
    final hostFirst =
        mode == CockpitRecordingMode.auto || mode == CockpitRecordingMode.full;
    if (hostFirst && host != null) {
      ordered.add(host);
    }
    ordered.add(remote);
    if (!hostFirst && host != null) {
      ordered.add(host);
    }
    return ordered;
  }

  List<_RecordingCandidate> _desktopCandidates({
    required CockpitRecordingMode mode,
    required _RecordingCandidate remote,
    required _RecordingCandidate? host,
    required bool preferActiveHostSession,
  }) {
    final ordered = <_RecordingCandidate>[];
    final activeHost = preferActiveHostSession &&
        host != null &&
        host.sessionKey != null &&
        cockpitHasActiveHostRecordingSession(host.sessionKey!);
    if (activeHost) {
      ordered.add(host);
      ordered.add(remote);
      return ordered;
    }
    if (preferActiveHostSession) {
      ordered.add(remote);
      if (host != null) {
        ordered.add(host);
      }
      return ordered;
    }
    if (mode == CockpitRecordingMode.full && host != null) {
      ordered.add(host);
    }
    ordered.add(remote);
    if (mode != CockpitRecordingMode.full && host != null) {
      ordered.add(host);
    }
    return ordered;
  }

  CockpitRecordingLayer? _preferredLayerForMode(
    String platform,
    CockpitRecordingMode mode,
  ) {
    return switch (mode) {
      CockpitRecordingMode.auto ||
      CockpitRecordingMode.cheap =>
        _remoteLayerForPlatform(platform),
      CockpitRecordingMode.native => switch (platform) {
          'web' => null,
          _ => _remoteLayerForPlatform(platform),
        },
      CockpitRecordingMode.full => switch (platform) {
          'macos' || 'windows' || 'linux' => CockpitRecordingLayer.hostScreen,
          _ => _remoteLayerForPlatform(platform),
        },
    };
  }

  CockpitRecordingLayer _remoteLayerForPlatform(String platform) {
    return switch (platform) {
      'android' || 'ios' => CockpitRecordingLayer.system,
      'web' => CockpitRecordingLayer.hostScreen,
      _ => CockpitRecordingLayer.appWindow,
    };
  }

  _RecordingCandidate _closestLayerCandidate(
    List<_RecordingCandidate> candidates,
    CockpitRecordingLayer desiredLayer,
  ) {
    var best = candidates.first;
    var bestScore = _fallbackDistance(best.layer, desiredLayer);
    for (final candidate in candidates.skip(1)) {
      final score = _fallbackDistance(candidate.layer, desiredLayer);
      if (score < bestScore ||
          (score == bestScore &&
              candidate.layer.coverageRank > best.layer.coverageRank)) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  int _fallbackDistance(
    CockpitRecordingLayer candidate,
    CockpitRecordingLayer desired,
  ) {
    return (candidate.coverageRank - desired.coverageRank).abs();
  }

  static CockpitRecordingAdapter _defaultRemoteAdapterFactory(
    CockpitRemoteSessionClient client,
  ) {
    return CockpitRemoteRecordingAdapter(client: client);
  }

  static CockpitRecordingAdapter _defaultAdbAdapterFactory(String deviceId) {
    return CockpitAdbRecordingAdapter(deviceId: deviceId);
  }

  static CockpitRecordingAdapter _defaultSimctlAdapterFactory(String deviceId) {
    return CockpitSimctlRecordingAdapter(deviceId: deviceId);
  }

  static CockpitRecordingAdapter _defaultMacosAdapterFactory(String appId) {
    return CockpitMacosRecordingAdapter(appId: appId);
  }

  static CockpitRecordingAdapter _defaultWindowsAdapterFactory(String appId) {
    return CockpitWindowsRecordingAdapter(appId: appId);
  }

  static CockpitRecordingAdapter _defaultLinuxAdapterFactory(String appId) {
    return CockpitLinuxRecordingAdapter(appId: appId);
  }
}

final class _RecordingCandidate {
  const _RecordingCandidate({
    required this.implementation,
    required this.layer,
    required this.factory,
    this.sessionKey,
  });

  final String implementation;
  final CockpitRecordingLayer layer;
  final CockpitRecordingAdapter Function() factory;
  final String? sessionKey;
}

final class _PolicyAwareRecordingAdapter implements CockpitRecordingAdapter {
  const _PolicyAwareRecordingAdapter({
    required CockpitRecordingAdapter delegate,
    required CockpitRecordingMode requestedMode,
    required CockpitRecordingLayer? requestedLayer,
    required CockpitRecordingLayer effectiveLayer,
    required bool fallbackUsed,
    required String? fallbackReason,
  })  : _delegate = delegate,
        _requestedMode = requestedMode,
        _requestedLayer = requestedLayer,
        _effectiveLayer = effectiveLayer,
        _fallbackUsed = fallbackUsed,
        _fallbackReason = fallbackReason;

  final CockpitRecordingAdapter _delegate;
  final CockpitRecordingMode _requestedMode;
  final CockpitRecordingLayer? _requestedLayer;
  final CockpitRecordingLayer _effectiveLayer;
  final bool _fallbackUsed;
  final String? _fallbackReason;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    return _delegate.startRecording(request);
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    final result = await _delegate.stopRecording();
    return result.copyWith(
      requestedMode: result.requestedMode ?? _requestedMode,
      requestedLayer: result.requestedLayer ?? _requestedLayer,
      effectiveLayer: result.effectiveLayer ?? _effectiveLayer,
      fallbackUsed: result.fallbackUsed || _fallbackUsed,
      fallbackReason: result.fallbackReason ?? _fallbackReason,
    );
  }
}
