import 'cockpit_mcp_resource_definition.dart';

final class CockpitMcpResourceRequest {
  const CockpitMcpResourceRequest({required this.uri});

  final String uri;

  Uri get parsedUri => Uri.parse(uri);
}

sealed class CockpitMcpResourceContents {
  const CockpitMcpResourceContents({required this.uri, this.mimeType});

  final String uri;
  final String? mimeType;
}

final class CockpitMcpTextResourceContents extends CockpitMcpResourceContents {
  const CockpitMcpTextResourceContents({
    required super.uri,
    required this.text,
    super.mimeType,
  });

  final String text;
}

final class CockpitMcpResourceResult {
  const CockpitMcpResourceResult({required this.contents});

  final List<CockpitMcpResourceContents> contents;
}

abstract base class CockpitMcpResource {
  const CockpitMcpResource();

  CockpitMcpResourceDefinition get definition;

  Future<CockpitMcpResourceResult?> read(CockpitMcpResourceRequest request);
}
