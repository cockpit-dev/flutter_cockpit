import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/control_core/cockpit_control_planner.dart';
import 'package:flutter_cockpit_devtools/src/control_core/cockpit_intent.dart';
import 'package:test/test.dart';

void main() {
  test('planner prefers flutter semantic plane before device fallback', () {
    final planner = CockpitControlPlanner();
    final plan = planner.plan(
      intent: CockpitIntent.tap(
        locator: const CockpitLocator(text: 'Submit'),
      ),
      capabilityProfile: CockpitCapabilityProfile(
        targetKind: CockpitTargetKind.flutterApp,
        surfaceKinds: <CockpitSurfaceKind>{
          CockpitSurfaceKind.flutterSemantic,
          CockpitSurfaceKind.nativeUi,
        },
        actionCapabilities: <CockpitActionCapability>{
          CockpitActionCapability.tap,
        },
        evidenceCapabilities: <CockpitEvidenceCapability>{
          CockpitEvidenceCapability.flutterScreenshot,
        },
      ),
    );

    expect(plan.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
    expect(plan.candidatePlanes, <CockpitPlaneKind>[
      CockpitPlaneKind.flutterSemanticPlane,
      CockpitPlaneKind.nativeUiPlane,
      CockpitPlaneKind.deviceSystemPlane,
    ]);
    expect(plan.fallbackChain, <CockpitPlaneKind>[
      CockpitPlaneKind.nativeUiPlane,
      CockpitPlaneKind.deviceSystemPlane,
    ]);
    expect(plan.requiresObservation, isTrue);
  });

  test('planner routes host shell work directly to the host plane', () {
    final planner = CockpitControlPlanner();
    final plan = planner.plan(
      intent: CockpitIntent.runHostShell(
        command: const <String>['dart', '--version'],
      ),
      capabilityProfile: CockpitCapabilityProfile(
        targetKind: CockpitTargetKind.hostWorkspace,
        surfaceKinds: <CockpitSurfaceKind>{CockpitSurfaceKind.hostShell},
        actionCapabilities: <CockpitActionCapability>{
          CockpitActionCapability.runShell,
        },
      ),
    );

    expect(plan.selectedPlane, CockpitPlaneKind.hostPlane);
    expect(
        plan.candidatePlanes, <CockpitPlaneKind>[CockpitPlaneKind.hostPlane]);
    expect(plan.fallbackChain, isEmpty);
    expect(plan.requiresObservation, isFalse);
  });
}
