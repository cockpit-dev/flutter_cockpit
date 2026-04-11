import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capability profile serializes additive multi-plane support', () {
    final profile = CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.tap,
        CockpitActionCapability.captureScreenshot,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.flutterScreenshot,
        CockpitEvidenceCapability.nativeScreenshot,
      },
      qualityFlags: <CockpitQualityFlag>{
        CockpitQualityFlag.requiresForegroundWindow,
      },
    );

    expect(CockpitCapabilityProfile.fromJson(profile.toJson()), profile);
    expect(profile.toJson()['targetKind'], 'flutterApp');
    expect(profile.supportsSurface(CockpitSurfaceKind.nativeUi), isTrue);
    expect(
      profile.supportsAction(CockpitActionCapability.captureScreenshot),
      isTrue,
    );
    expect(
      profile.supportsEvidence(CockpitEvidenceCapability.nativeScreenshot),
      isTrue,
    );
  });

  test('capabilities preserve legacy booleans and capability profile', () {
    final capabilities = CockpitCapabilities(
      platform: 'android',
      transportType: 'remoteHttp',
      supportsInAppControl: true,
      supportsFlutterViewCapture: true,
      supportsNativeScreenCapture: true,
      supportsHostAutomation: false,
      supportedCommands: <CockpitCommandType>[
        CockpitCommandType.tap,
        CockpitCommandType.captureScreenshot,
      ],
      supportedLocatorStrategies: CockpitLocatorKind.values,
      capabilityProfile: CockpitCapabilityProfile(
        targetKind: CockpitTargetKind.flutterApp,
        surfaceKinds: <CockpitSurfaceKind>{
          CockpitSurfaceKind.flutterSemantic,
          CockpitSurfaceKind.nativeUi,
        },
        actionCapabilities: <CockpitActionCapability>{
          CockpitActionCapability.tap,
          CockpitActionCapability.captureScreenshot,
        },
        evidenceCapabilities: <CockpitEvidenceCapability>{
          CockpitEvidenceCapability.flutterScreenshot,
        },
      ),
    );

    expect(CockpitCapabilities.fromJson(capabilities.toJson()), capabilities);
    expect(capabilities.toJson()['supportsInAppControl'], isTrue);
    expect(capabilities.toJson()['capabilityProfile'],
        isA<Map<String, Object?>>());
  });
}
