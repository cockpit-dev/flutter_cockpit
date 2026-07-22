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

  test(
    'trusted development policy allows declared sensitive effects only in non-production environments',
    () async {
      final policy = CockpitTrustedDevelopmentSafetyPolicy(
        environments: const <CockpitTestTargetEnvironment>{
          CockpitTestTargetEnvironment.development,
          CockpitTestTargetEnvironment.test,
          CockpitTestTargetEnvironment.staging,
        },
        allowedEffects: const <CockpitTestSafetyEffect>{
          CockpitTestSafetyEffect.credentialSensitive,
        },
      );
      final declaration = CockpitTestSafetyDeclaration(
        effects: const <CockpitTestSafetyEffect>{
          CockpitTestSafetyEffect.credentialSensitive,
        },
        reason: 'Authenticate the test session.',
      );

      for (final environment in const <CockpitTestTargetEnvironment>[
        CockpitTestTargetEnvironment.development,
        CockpitTestTargetEnvironment.test,
        CockpitTestTargetEnvironment.staging,
      ]) {
        expect(
          await cockpitAuthorizeTestAction(
            policy: policy,
            request: _secretRequest(environment, declaration),
          ),
          isNull,
          reason: environment.name,
        );
      }
      for (final environment in const <CockpitTestTargetEnvironment>[
        CockpitTestTargetEnvironment.production,
        CockpitTestTargetEnvironment.unknown,
      ]) {
        expect(
          await cockpitAuthorizeTestAction(
            policy: policy,
            request: _secretRequest(environment, declaration),
          ),
          isA<CockpitTestError>().having(
            (error) => error.code,
            'code',
            CockpitTestErrorCode.safetyDenied,
          ),
          reason: environment.name,
        );
      }
    },
  );

  test(
    'trusted development policy rejects undeclared secret effects',
    () async {
      final policy = CockpitTrustedDevelopmentSafetyPolicy(
        environments: const <CockpitTestTargetEnvironment>{
          CockpitTestTargetEnvironment.development,
        },
      );

      final error = await cockpitAuthorizeTestAction(
        policy: policy,
        request: _secretRequest(
          CockpitTestTargetEnvironment.development,
          CockpitTestSafetyDeclaration(),
        ),
      );

      expect(error?.code, CockpitTestErrorCode.safetyDenied);
    },
  );

  test('trusted development policy denies effects by default', () async {
    final policy = CockpitTrustedDevelopmentSafetyPolicy(
      environments: const <CockpitTestTargetEnvironment>{
        CockpitTestTargetEnvironment.development,
      },
    );

    final error = await cockpitAuthorizeTestAction(
      policy: policy,
      request: _secretRequest(
        CockpitTestTargetEnvironment.development,
        CockpitTestSafetyDeclaration(
          effects: const <CockpitTestSafetyEffect>{
            CockpitTestSafetyEffect.credentialSensitive,
          },
        ),
      ),
    );

    expect(error?.code, CockpitTestErrorCode.safetyDenied);
  });

  test('declarations cannot expand credential-only authority', () async {
    final policy = CockpitTrustedDevelopmentSafetyPolicy(
      environments: const <CockpitTestTargetEnvironment>{
        CockpitTestTargetEnvironment.development,
      },
      allowedEffects: const <CockpitTestSafetyEffect>{
        CockpitTestSafetyEffect.credentialSensitive,
      },
    );
    for (final effect in CockpitTestSafetyEffect.values.where(
      (effect) => effect != CockpitTestSafetyEffect.credentialSensitive,
    )) {
      final error = await cockpitAuthorizeTestAction(
        policy: policy,
        request: _secretRequest(
          CockpitTestTargetEnvironment.development,
          CockpitTestSafetyDeclaration(
            effects: <CockpitTestSafetyEffect>{
              CockpitTestSafetyEffect.credentialSensitive,
              effect,
            },
          ),
        ),
      );
      expect(
        error?.code,
        CockpitTestErrorCode.safetyDenied,
        reason: effect.name,
      );
    }
  });

  test('trusted policy cannot authorize production or unknown', () {
    for (final environment in const <CockpitTestTargetEnvironment>[
      CockpitTestTargetEnvironment.production,
      CockpitTestTargetEnvironment.unknown,
    ]) {
      expect(
        () => CockpitTrustedDevelopmentSafetyPolicy(
          environments: <CockpitTestTargetEnvironment>{environment},
          allowedEffects: CockpitTestSafetyEffect.values,
        ),
        throwsArgumentError,
        reason: environment.name,
      );
    }
  });
}

CockpitTestSafetyRequest _secretRequest(
  CockpitTestTargetEnvironment environment,
  CockpitTestSafetyDeclaration declaration,
) => CockpitTestSafetyRequest(
  phase: CockpitTestSafetyPhase.dispatch,
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
  targetEnvironment: environment,
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
  declaration: declaration,
  isMutation: true,
);

final class _AllowAllPolicy implements CockpitTestSafetyPolicy {
  const _AllowAllPolicy();

  @override
  Future<CockpitTestSafetyDecision> authorize(
    CockpitTestSafetyRequest request,
  ) async => const CockpitTestSafetyDecision.allow();
}
