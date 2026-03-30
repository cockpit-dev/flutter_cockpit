import '../../application/cockpit_validate_task_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitValidateTaskWorkflowFunction = Future<CockpitValidateTaskResult>
    Function(
  CockpitValidateTaskRequest request,
);

final class CockpitValidateTaskTool extends CockpitMcpTool {
  CockpitValidateTaskTool({
    CockpitValidateTaskService? service,
    CockpitValidateTaskWorkflowFunction? validateTask,
  }) : _validateTask =
            validateTask ?? (service ?? CockpitValidateTaskService()).validate;

  final CockpitValidateTaskWorkflowFunction _validateTask;

  @override
  String get name => 'validate_task';

  @override
  String get description =>
      'Run a flutter_cockpit task workflow and validate the persisted bundle as a delivery-ready artifact set.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: false,
        destructive: false,
        idempotent: false,
        longRunning: true,
        requiresSession: false,
        producesBundleEvidence: true,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.delivery,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['run_task'],
        'properties': <String, Object?>{
          'run_task': <String, Object?>{'type': 'object'},
          'validation': <String, Object?>{'type': 'object'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final request = CockpitValidateTaskRequest.fromJson(arguments);
      final result = await _validateTask(request);

      return cockpitMcpResult(
        text: 'Task workflow executed and validated.',
        structuredContent: <String, Object?>{
          'classification': result.classification.jsonValue,
          'recommended_next_step': result.recommendedNextStep,
          'blocked_reason': result.blockedReason,
          'validation_failures': result.validationFailures
              .map((failure) => failure.toJson())
              .toList(growable: false),
          'run_task_result': result.runTaskResult?.toJson(),
          'bundle_summary': result.bundleSummary?.toMcpJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
