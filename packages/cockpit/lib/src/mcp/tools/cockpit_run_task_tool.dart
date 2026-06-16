import '../../application/cockpit_run_task_service.dart';
import '../../application/cockpit_latest_task_store.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunTaskOrchestrationFunction =
    Future<CockpitRunTaskResult> Function(CockpitRunTaskRequest request);

final class CockpitRunTaskTool extends CockpitMcpTool {
  CockpitRunTaskTool({
    CockpitRunTaskService? service,
    CockpitRunTaskOrchestrationFunction? runTask,
    CockpitLatestTaskStore? latestTaskStore,
  }) : _runTask = runTask ?? (service ?? CockpitRunTaskService()).run,
       _latestTaskStore = latestTaskStore;

  final CockpitRunTaskOrchestrationFunction _runTask;
  final CockpitLatestTaskStore? _latestTaskStore;

  @override
  String get name => 'run_task';

  @override
  String get description =>
      'Run a full flutter_cockpit workflow with bootstrap or reuse, baseline capture, execution, post-run bundle reads, and task classification.';

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
        CockpitMcpFeatureCategory.execution,
        CockpitMcpFeatureCategory.delivery,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'required': <String>['script', 'outputRoot'],
    'properties': <String, Object?>{
      'launch': <String, Object?>{'type': 'object'},
      'sessionHandle': <String, Object?>{'type': 'object'},
      'sessionHandlePath': <String, Object?>{'type': 'string'},
      'script': <String, Object?>{'type': 'object'},
      'outputRoot': <String, Object?>{'type': 'string'},
      'persistScriptPath': <String, Object?>{'type': 'string'},
      'baseline': <String, Object?>{'type': 'object'},
      'requirements': <String, Object?>{'type': 'object'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final request = CockpitRunTaskRequest.fromJson(arguments);
      final result = await _runTask(request);
      _latestTaskStore?.recordRunTask(result);

      return cockpitMcpResult(
        text: 'Task workflow executed and classified.',
        structuredContent: <String, Object?>{
          'classification': result.classification.jsonValue,
          'recommendedNextStep': result.recommendedNextStep,
          'sessionHandle': result.sessionHandle?.toJson(),
          'preflightStatus': result.preflightStatus?.toJson(),
          'blockedReason': result.blockedReason,
          'warnings': result.warnings,
          'bundleSummary': result.bundleSummary?.toMcpJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
