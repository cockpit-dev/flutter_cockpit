import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cockpit_system_control_action.dart';
import '../cockpit_system_control_adapter.dart';
import '../cockpit_system_control_profile.dart';

final class CockpitDesktopSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitDesktopSystemControlAdapter({
    required this.platform,
    required this.adapter,
    required this.inputStrategy,
    required this.screenshotStrategy,
    required this.recordingStrategy,
    required this.requires,
    this.limitations = const <String>[],
  });

  @override
  final String platform;
  final String adapter;
  final String inputStrategy;
  final String screenshotStrategy;
  final String recordingStrategy;
  final List<String> requires;
  final List<String> limitations;

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    final hasWindowTarget = platform == 'macos'
        ? target.appId != null && target.appId!.trim().isNotEmpty
        : target.hasWindowTarget;
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: target.deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: adapter,
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
        CockpitPlaneKind.deviceSystemPlane,
        CockpitPlaneKind.hostPlane,
      ],
      recommendedNextStep: 'preferFlutterSemanticPlane',
      capabilities: <CockpitSystemControlCapability>[
        _blocked(CockpitSystemControlAction.tap, inputStrategy),
        _blocked(CockpitSystemControlAction.typeText, inputStrategy),
        _blocked(CockpitSystemControlAction.activateWindow, inputStrategy),
        _blocked(CockpitSystemControlAction.dismissSystemDialog, inputStrategy),
        _evidenceCapability(
          CockpitSystemControlAction.captureScreenshot,
          screenshotStrategy,
          hasWindowTarget: hasWindowTarget,
        ),
        _evidenceCapability(
          CockpitSystemControlAction.startRecording,
          recordingStrategy,
          hasWindowTarget: hasWindowTarget,
        ),
        _evidenceCapability(
          CockpitSystemControlAction.stopRecording,
          recordingStrategy,
          hasWindowTarget: hasWindowTarget,
          extraRequires: const <String>['active recording session'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.runShell,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.available,
          strategy: 'host.shell',
          limitations: limitations,
        ),
      ],
    );
  }

  @override
  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  ) {
    if (request.action != CockpitSystemControlAction.runShell) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'systemActionBlocked',
        message:
            'This desktop action requires a platform-specific native adapter.',
      );
    }
    return cockpitShellCommand(
      request,
      (command) => CockpitResolvedSystemControlCommand(
        command.first,
        command.skip(1).toList(growable: false),
      ),
    );
  }

  CockpitSystemControlCapability _blocked(
    CockpitSystemControlAction action,
    String strategy,
  ) {
    return CockpitSystemControlCapability(
      action: action,
      plane:
          action == CockpitSystemControlAction.captureScreenshot ||
              action == CockpitSystemControlAction.startRecording ||
              action == CockpitSystemControlAction.stopRecording
          ? CockpitPlaneKind.hostPlane
          : CockpitPlaneKind.nativeUiPlane,
      availability: CockpitSystemControlAvailability.blocked,
      strategy: strategy,
      requires: requires,
      limitations: limitations,
    );
  }

  CockpitSystemControlCapability _evidenceCapability(
    CockpitSystemControlAction action,
    String strategy, {
    required bool hasWindowTarget,
    List<String> extraRequires = const <String>[],
  }) {
    return CockpitSystemControlCapability(
      action: action,
      plane: CockpitPlaneKind.hostPlane,
      availability: hasWindowTarget
          ? CockpitSystemControlAvailability.available
          : CockpitSystemControlAvailability.blocked,
      strategy: strategy,
      requires: <String>[
        ...requires,
        if (!hasWindowTarget) 'app id or process id',
        ...extraRequires,
      ],
      limitations: limitations,
    );
  }
}

final class CockpitWebSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitWebSystemControlAdapter();

  @override
  String get platform => 'web';

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: target.deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: 'browser.dom+host-recording',
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
        CockpitPlaneKind.hostPlane,
      ],
      recommendedNextStep: 'preferFlutterSemanticPlane',
      capabilities: const <CockpitSystemControlCapability>[
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.tap,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.dom.click',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.typeText,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.dom.input',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.captureScreenshot,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.screenshot',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.startRecording,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser-host-recording',
          requires: <String>['ffmpeg', 'host screen capture permission'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.stopRecording,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser-host-recording.stop',
          requires: <String>[
            'ffmpeg',
            'host screen capture permission',
            'active recording session',
          ],
        ),
      ],
    );
  }

  @override
  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'systemActionBlocked',
      message:
          'Browser system actions require an active browser bridge; use Flutter or browser-specific target tools.',
    );
  }
}

final class CockpitUnsupportedSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitUnsupportedSystemControlAdapter(this.platform);

  @override
  final String platform;

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: target.deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: 'unsupported',
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.hostPlane,
      ],
      recommendedNextStep: 'useFlutterOrHostFallback',
      capabilities: CockpitSystemControlAction.values
          .map(
            (action) => CockpitSystemControlCapability(
              action: action,
              plane: CockpitPlaneKind.hostPlane,
              availability: CockpitSystemControlAvailability.unsupported,
              strategy: 'unsupported',
              limitations: <String>['No system control adapter for $platform'],
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'unsupportedPlatform',
      message: 'No system control adapter for $platform.',
    );
  }
}
