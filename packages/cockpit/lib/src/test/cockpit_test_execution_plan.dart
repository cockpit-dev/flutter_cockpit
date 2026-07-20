import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_test_secret_resolver.dart';

final class CockpitTestExecutionPlan {
  CockpitTestExecutionPlan({
    required this.caseId,
    required this.sourceSha256,
    required this.target,
    required this.defaults,
    required Iterable<CockpitTestExecutionNode> setup,
    required Iterable<CockpitTestExecutionNode> steps,
    required Iterable<CockpitTestExecutionNode> finallySteps,
    required this.secretBindings,
  }) : setup = List<CockpitTestExecutionNode>.unmodifiable(setup),
       steps = List<CockpitTestExecutionNode>.unmodifiable(steps),
       finallySteps = List<CockpitTestExecutionNode>.unmodifiable(finallySteps);

  final String caseId;
  final String sourceSha256;
  final CockpitTestTargetRequirements target;
  final CockpitTestCaseDefaults defaults;
  final List<CockpitTestExecutionNode> setup;
  final List<CockpitTestExecutionNode> steps;
  final List<CockpitTestExecutionNode> finallySteps;
  final CockpitTestSecretBindings secretBindings;

  Iterable<CockpitTestExecutionNode> get allNodes sync* {
    Iterable<CockpitTestExecutionNode> flatten(
      Iterable<CockpitTestExecutionNode> nodes,
    ) sync* {
      for (final node in nodes) {
        yield node;
        switch (node.operation) {
          case CockpitTestIfPlanOperation(:final thenSteps, :final elseSteps):
            yield* flatten(thenSteps);
            yield* flatten(elseSteps);
          case CockpitTestRetryPlanOperation(:final steps) ||
              CockpitTestLoopPlanOperation(:final steps):
            yield* flatten(steps);
          default:
            break;
        }
      }
    }

    yield* flatten(setup);
    yield* flatten(steps);
    yield* flatten(finallySteps);
  }
}

final class CockpitTestExecutionNode {
  CockpitTestExecutionNode({
    required this.stepId,
    required this.executionId,
    required this.section,
    this.description,
    required this.timeoutMs,
    required this.evidence,
    required this.safety,
    required this.sourcePath,
    this.sourceLocation,
    Iterable<String> callPath = const <String>[],
    required this.operation,
  }) : callPath = List<String>.unmodifiable(callPath);

  final String stepId;
  final String executionId;
  final String section;
  final String? description;
  final int timeoutMs;
  final CockpitTestEvidencePolicy evidence;
  final CockpitTestSafetyDeclaration safety;
  final String sourcePath;
  final CockpitTestSourceLocation? sourceLocation;
  final List<String> callPath;
  final CockpitTestPlanOperation operation;
}

sealed class CockpitTestPlanOperation {
  const CockpitTestPlanOperation();
}

final class CockpitTestActionPlanOperation extends CockpitTestPlanOperation {
  const CockpitTestActionPlanOperation(this.action);

  final CockpitTestAction action;
}

final class CockpitTestStartRecordingPlanOperation
    extends CockpitTestPlanOperation {
  const CockpitTestStartRecordingPlanOperation({
    required this.name,
    required this.purpose,
    required this.mode,
    this.layer,
    this.allowFallback,
    required this.attachToStep,
  });

  final String name;
  final String purpose;
  final String mode;
  final String? layer;
  final bool? allowFallback;
  final bool attachToStep;
}

final class CockpitTestStopRecordingPlanOperation
    extends CockpitTestPlanOperation {
  const CockpitTestStopRecordingPlanOperation({required this.settleMs});

  final int settleMs;
}

final class CockpitTestIfPlanOperation extends CockpitTestPlanOperation {
  CockpitTestIfPlanOperation({
    required this.condition,
    required Iterable<CockpitTestExecutionNode> thenSteps,
    required Iterable<CockpitTestExecutionNode> elseSteps,
  }) : thenSteps = List<CockpitTestExecutionNode>.unmodifiable(thenSteps),
       elseSteps = List<CockpitTestExecutionNode>.unmodifiable(elseSteps);

  final CockpitTestCondition condition;
  final List<CockpitTestExecutionNode> thenSteps;
  final List<CockpitTestExecutionNode> elseSteps;
}

final class CockpitTestRetryPlanOperation extends CockpitTestPlanOperation {
  CockpitTestRetryPlanOperation({
    required this.maxAttempts,
    required this.delayMs,
    required Iterable<CockpitTestExecutionNode> steps,
  }) : steps = List<CockpitTestExecutionNode>.unmodifiable(steps);

  final int maxAttempts;
  final int delayMs;
  final List<CockpitTestExecutionNode> steps;
}

final class CockpitTestLoopPlanOperation extends CockpitTestPlanOperation {
  CockpitTestLoopPlanOperation({
    required this.maxIterations,
    required this.condition,
    required Iterable<CockpitTestExecutionNode> steps,
  }) : steps = List<CockpitTestExecutionNode>.unmodifiable(steps);

  final int maxIterations;
  final CockpitTestCondition condition;
  final List<CockpitTestExecutionNode> steps;
}

final class CockpitTestBindingException implements Exception {
  const CockpitTestBindingException(this.error);

  final CockpitTestError error;

  @override
  String toString() =>
      'CockpitTestBindingException(${error.code.name}): '
      '${error.message}';
}
