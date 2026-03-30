import 'package:dart_mcp/server.dart';

import 'cockpit_mcp_resource.dart';

final class CockpitMcpResourceAdapter {
  const CockpitMcpResourceAdapter._();

  static Resource? fixedResourceFor(CockpitMcpResource resource) {
    final definition = resource.definition;
    final uri = definition.uri;
    if (uri == null) {
      return null;
    }

    return Resource(
      uri: uri,
      name: definition.name,
      description: definition.description,
      mimeType: definition.mimeType,
    );
  }

  static ResourceTemplate? templateFor(CockpitMcpResource resource) {
    final definition = resource.definition;
    final uriTemplate = definition.uriTemplate;
    if (uriTemplate == null) {
      return null;
    }

    return ResourceTemplate(
      uriTemplate: uriTemplate,
      name: definition.name,
      description: definition.description,
      mimeType: definition.mimeType,
    );
  }

  static Future<ReadResourceResult?> invoke(
    CockpitMcpResource resource,
    ReadResourceRequest request,
  ) async {
    final result = await resource.read(
      CockpitMcpResourceRequest(uri: request.uri),
    );
    if (result == null) {
      return null;
    }

    return ReadResourceResult(
      contents: result.contents.map(_convertContents).toList(growable: false),
    );
  }

  static ResourceContents _convertContents(
      CockpitMcpResourceContents contents) {
    return switch (contents) {
      CockpitMcpTextResourceContents() => TextResourceContents(
          uri: contents.uri,
          text: contents.text,
          mimeType: contents.mimeType,
        ),
    };
  }
}
