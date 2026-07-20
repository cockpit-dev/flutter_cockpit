import 'package:cockpit/cockpit.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('secret actions require credential-sensitive classification', () async {
    final error = await cockpitAuthorizeTestAction(
      policy: const _AllowAllPolicy(),
      request: CockpitTestSafetyRequest(
        phase: CockpitTestSafetyPhase.preflight,
        runContext: CockpitTestRunContext(
          projectId: 'projectOne',
          workspaceId: 'workspaceOne',
          runId: 'runOne',
          caseId: 'secretCase',
          attemptId: 'attemptOne',
          engineVersion: '2.0.0',
        ),
        target: CockpitTestTargetRequirements(
          platform: 'android',
          targetKind: 'flutterApp',
          plane: CockpitTestPlane.semantic,
        ),
        targetEnvironment: CockpitTestTargetEnvironment.test,
        stepId: 'enterPassword',
        executionId: 'main/enterPassword',
        action: CockpitTestAction(
          kind: CockpitTestActionKind.enterText,
          values: <CockpitTestActionField, Object?>{
            CockpitTestActionField.text: CockpitTestSecretToken(
              'opaque-secret-token',
            ),
          },
        ),
        declaration: CockpitTestSafetyDeclaration(),
        isMutation: true,
      ),
    );

    expect(error?.code, CockpitTestErrorCode.safetyDenied);
  });
}

final class _AllowAllPolicy implements CockpitTestSafetyPolicy {
  const _AllowAllPolicy();

  @override
  Future<CockpitTestSafetyDecision> authorize(
    CockpitTestSafetyRequest request,
  ) async => const CockpitTestSafetyDecision.allow();
}
