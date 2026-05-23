import 'package:dart_mcp/server.dart';

import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

final class CockpitMcpToolAdapter {
  const CockpitMcpToolAdapter._();

  static Tool protocolToolFor(CockpitMcpTool tool) {
    final definition = tool.definition;
    return Tool(
      name: definition.name,
      description: definition.description,
      inputSchema: ObjectSchema.fromMap(
        cockpitNormalizeMcpInputSchema(definition.inputSchema),
      ),
      annotations: ToolAnnotations(
        destructiveHint: definition.annotations.destructive,
        idempotentHint: definition.annotations.idempotent,
        openWorldHint: !definition.annotations.readOnly,
        readOnlyHint: definition.annotations.readOnly,
        title: _titleFor(definition.name),
      ),
    );
  }

  static Future<CallToolResult> invoke(
    CockpitMcpTool tool,
    Map<String, Object?> arguments,
  ) async {
    try {
      final result = await tool.call(arguments);
      return CallToolResult(
        content: _contentFromResult(result),
        structuredContent: _structuredContentFromResult(result),
        isError: result['isError'] as bool?,
      );
    } on CockpitMcpError catch (error) {
      return CallToolResult(
        isError: true,
        content: <Content>[TextContent(text: error.message)],
        structuredContent: <String, Object?>{'error': error.toJson()},
      );
    } on Object catch (error) {
      return CallToolResult(
        isError: true,
        content: <Content>[TextContent(text: error.toString())],
      );
    }
  }

  static List<Content> _contentFromResult(Map<String, Object?> result) {
    final rawContent =
        (result['content'] as List<Object?>?) ?? const <Object?>[];
    return rawContent
        .cast<Map<Object?, Object?>>()
        .map((entry) => _contentFromJson(Map<String, Object?>.from(entry)))
        .toList(growable: false);
  }

  static Content _contentFromJson(Map<String, Object?> json) {
    final type = json['type'];
    switch (type) {
      case 'text':
        return TextContent(text: json['text'] as String? ?? '');
      default:
        throw StateError('Unsupported MCP content type: $type');
    }
  }

  static Map<String, Object?>? _structuredContentFromResult(
    Map<String, Object?> result,
  ) {
    final structuredContent = result['structuredContent'];
    if (structuredContent is Map<Object?, Object?>) {
      return Map<String, Object?>.from(structuredContent);
    }
    return null;
  }

  static String _titleFor(String name) {
    return name
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
