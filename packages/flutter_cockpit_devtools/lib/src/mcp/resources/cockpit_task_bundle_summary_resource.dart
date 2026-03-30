import 'dart:convert';

import '../../application/cockpit_read_task_bundle_summary_service.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitTaskBundleSummaryResource extends CockpitMcpResource {
  CockpitTaskBundleSummaryResource({
    CockpitReadTaskBundleSummaryService? service,
  }) : _service = service ?? const CockpitReadTaskBundleSummaryService();

  final CockpitReadTaskBundleSummaryService _service;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.template(
        name: 'task_bundle_summary',
        uriTemplate: 'cockpit://task/summary{?bundle_dir}',
        description:
            'Read a task bundle summary directly as a resource for inspection and delivery review.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.delivery,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
      CockpitMcpResourceRequest request) async {
    final uri = request.parsedUri;
    if (uri.host != 'task' || uri.path != '/summary') {
      return null;
    }
    final bundleDir = uri.queryParameters['bundle_dir'];
    if (bundleDir == null || bundleDir.isEmpty) {
      throw StateError('task bundle summary resource requires bundle_dir.');
    }
    final result = await _service.read(
      CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir),
    );
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: const JsonEncoder.withIndent('  ').convert(result.toJson()),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
