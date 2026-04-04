import '../../application/cockpit_read_task_bundle_summary_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadTaskBundleSummaryFunction
    = Future<CockpitReadTaskBundleSummaryResult> Function(
  CockpitReadTaskBundleSummaryRequest request,
);

final class CockpitReadTaskBundleSummaryTool extends CockpitMcpTool {
  CockpitReadTaskBundleSummaryTool({
    CockpitReadTaskBundleSummaryService? service,
    CockpitReadTaskBundleSummaryFunction? read,
  }) : _read = read ??
            (service ?? const CockpitReadTaskBundleSummaryService()).read;

  final CockpitReadTaskBundleSummaryFunction _read;

  @override
  String get name => 'read_task_bundle_summary';

  @override
  String get description =>
      'Read a flutter_cockpit task-run bundle and return delivery-oriented summary data.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['bundle_dir'],
        'properties': <String, Object?>{
          'bundleDir': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _read(
        CockpitReadTaskBundleSummaryRequest(
          bundleDir: cockpitReadRequiredString(arguments, 'bundle_dir'),
        ),
      );

      return cockpitMcpResult(
        text: 'Task bundle summary loaded.',
        structuredContent: result.toMcpJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
