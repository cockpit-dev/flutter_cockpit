import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_inspect_surface_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_inspect_ui_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/capture/cockpit_host_capture_adapter.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_evidence_driver.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_platform_driver.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_platform_driver_registry.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'inspect surface reuses flutter inspection for desktop targets when available',
    () async {
      final service = CockpitInspectSurfaceService(
        platformDriverRegistry: CockpitPlatformDriverRegistry(
          drivers: <String, CockpitPlatformDriverFactory>{
            'macos': ({required String deviceId}) =>
                _FakeEvidencePlatformDriver(
                  platform: 'macos',
                  capabilityProfile: CockpitCapabilityProfile(
                    targetKind: CockpitTargetKind.desktopApp,
                    surfaceKinds: <CockpitSurfaceKind>{
                      CockpitSurfaceKind.desktopWindow,
                      CockpitSurfaceKind.hostShell,
                    },
                    actionCapabilities: <CockpitActionCapability>{
                      CockpitActionCapability.captureScreenshot,
                    },
                    evidenceCapabilities: <CockpitEvidenceCapability>{
                      CockpitEvidenceCapability.windowCapture,
                    },
                  ),
                ),
          },
        ),
        inspectFlutterSurface: (_) async => const CockpitInspectUiResult(
          routeName: '/desktop-home',
          diagnosticLevel: 'inspect',
          truncated: false,
        ),
      );

      final result = await service.inspect(
        CockpitInspectSurfaceRequest(
          target: CockpitTargetHandle(
            targetId: 'dev.cockpit.desktop.macos',
            targetKind: CockpitTargetKind.desktopApp,
            platform: 'macos',
            deviceId: 'macos',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            connection: const CockpitTargetConnection(
              baseUrl: 'http://127.0.0.1:57331',
            ),
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );

      expect(result.routeName, '/desktop-home');
      expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
      expect(
        result.capabilityProfile.surfaceKinds,
        contains(CockpitSurfaceKind.flutterSemantic),
      );
      expect(result.recommendedNextStep, 'runNextCommand');
    },
  );

  test(
    'inspect surface falls back to native evidence for desktop targets when flutter inspection is unavailable',
    () async {
      final service = CockpitInspectSurfaceService(
        platformDriverRegistry: CockpitPlatformDriverRegistry(
          drivers: <String, CockpitPlatformDriverFactory>{
            'macos': ({required String deviceId}) =>
                _FakeEvidencePlatformDriver(
                  platform: 'macos',
                  capabilityProfile: CockpitCapabilityProfile(
                    targetKind: CockpitTargetKind.desktopApp,
                    surfaceKinds: const <CockpitSurfaceKind>{
                      CockpitSurfaceKind.desktopWindow,
                      CockpitSurfaceKind.hostShell,
                    },
                    actionCapabilities: const <CockpitActionCapability>{
                      CockpitActionCapability.captureScreenshot,
                    },
                    evidenceCapabilities: const <CockpitEvidenceCapability>{
                      CockpitEvidenceCapability.windowCapture,
                    },
                  ),
                  captureAdapter: _FakeHostCaptureAdapter(
                    execution: CockpitCommandExecution(
                      result: CockpitCommandResult(
                        success: true,
                        commandId: 'inspect-surface-capture',
                        commandType: CockpitCommandType.captureScreenshot,
                        durationMs: 42,
                        artifacts: const <CockpitArtifactRef>[
                          CockpitArtifactRef(
                            role: 'screenshot',
                            relativePath: 'screenshots/macos_inspect.png',
                          ),
                        ],
                        resolvedCaptureKind:
                            CockpitCaptureKind.nativeAcceptance,
                      ),
                      artifactSourcePaths: const <String, String>{
                        'screenshots/macos_inspect.png':
                            '/tmp/flutter_cockpit/macos_inspect.png',
                      },
                    ),
                  ),
                ),
          },
        ),
        inspectFlutterSurface: (_) async {
          throw const CockpitApplicationServiceException(
            code: 'remoteUnavailable',
            message: 'Remote flutter inspection is unavailable.',
          );
        },
      );

      final result = await service.inspect(
        CockpitInspectSurfaceRequest(
          target: CockpitTargetHandle(
            targetId: 'dev.cockpit.desktop.macos',
            targetKind: CockpitTargetKind.desktopApp,
            platform: 'macos',
            deviceId: 'macos',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            connection: const CockpitTargetConnection(
              baseUrl: 'http://127.0.0.1:57331',
            ),
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );

      expect(result.surfaceKind, CockpitSurfaceKind.desktopWindow);
      expect(result.selectedPlane, CockpitPlaneKind.nativeUiPlane);
      expect(result.snapshotRef, '/tmp/flutter_cockpit/macos_inspect.png');
      expect(result.recommendedNextStep, 'reviewCapture');
      expect(
        result.diagnostics?['artifacts'],
        isA<List<Object?>>(),
      );
    },
  );
}

final class _FakeEvidencePlatformDriver
    implements CockpitPlatformDriver, CockpitEvidenceDriver {
  const _FakeEvidencePlatformDriver({
    required this.platform,
    required this.capabilityProfile,
    this.captureAdapter,
  });

  @override
  final String platform;
  final CockpitCapabilityProfile capabilityProfile;
  @override
  final CockpitHostCaptureAdapter? captureAdapter;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    return capabilityProfile;
  }

  @override
  Null get recordingAdapter => null;
}

final class _FakeHostCaptureAdapter implements CockpitHostCaptureAdapter {
  const _FakeHostCaptureAdapter({required this.execution});

  final CockpitCommandExecution execution;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    return execution;
  }
}
