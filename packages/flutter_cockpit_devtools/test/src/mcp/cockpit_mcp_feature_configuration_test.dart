import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_feature_category.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_feature_configuration.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_tool_annotations.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_tool_definition.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitMcpFeatureConfiguration', () {
    const executionDefinition = CockpitMcpToolDefinition(
      name: 'run_task',
      description: 'Executes a closed-loop workflow.',
      inputSchema: <String, Object?>{'type': 'object'},
      annotations: CockpitMcpToolAnnotations(
        readOnly: false,
        destructive: false,
        idempotent: false,
        longRunning: true,
        requiresSession: false,
        producesBundleEvidence: true,
      ),
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.execution,
        CockpitMcpFeatureCategory.delivery,
      ],
      enabledByDefault: true,
    );

    test('returns the tool default when no overrides exist', () {
      const configuration = CockpitMcpFeatureConfiguration();

      expect(configuration.isEnabled(executionDefinition), isTrue);
    });

    test('disabling a category disables matching tools', () {
      const configuration = CockpitMcpFeatureConfiguration(
        disabledNames: <String>{'execution'},
      );

      expect(configuration.isEnabled(executionDefinition), isFalse);
    });

    test('disabling a tool by name wins over enabled categories', () {
      const configuration = CockpitMcpFeatureConfiguration(
        enabledNames: <String>{'delivery'},
        disabledNames: <String>{'run_task'},
      );

      expect(configuration.isEnabled(executionDefinition), isFalse);
    });

    test('enabling a tool by name wins over disabled categories', () {
      const configuration = CockpitMcpFeatureConfiguration(
        enabledNames: <String>{'run_task'},
        disabledNames: <String>{'execution'},
      );

      expect(configuration.isEnabled(executionDefinition), isTrue);
    });
  });
}
