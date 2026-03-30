import 'dart:async';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test('typed protocol server lists and calls cockpit tools', () async {
    final environment = _ProtocolTestEnvironment(
      tools: <CockpitMcpTool>[
        _FakeCockpitMcpTool(name: 'echo_tool'),
      ],
    );

    final connection = await environment.initialize();
    final listed = await connection.listTools();
    expect(listed.tools.map((tool) => tool.name), <String>['echo_tool']);

    final result = await connection.callTool(
      CallToolRequest(
        name: 'echo_tool',
        arguments: <String, Object?>{'value': 'hello'},
      ),
    );

    expect(result.isError, isNot(true));
    expect(
      result.content.single,
      isA<TextContent>().having((content) => content.text, 'text', 'hello'),
    );
    expect(result.structuredContent, <String, Object?>{'echoedValue': 'hello'});

    await environment.shutdown();
  });

  test('typed protocol server emits generic progress for long-running tools',
      () async {
    final environment = _ProtocolTestEnvironment(
      tools: <CockpitMcpTool>[
        _FakeCockpitMcpTool(
          name: 'long_task',
          annotations: const CockpitMcpToolAnnotations(
            readOnly: false,
            destructive: false,
            idempotent: false,
            longRunning: true,
            requiresSession: false,
            producesBundleEvidence: true,
          ),
          resultDelay: const Duration(milliseconds: 20),
        ),
      ],
    );

    final connection = await environment.initialize();
    final request = CallToolRequest(
      name: 'long_task',
      arguments: const <String, Object?>{'value': 'done'},
      meta: MetaWithProgressToken(progressToken: ProgressToken('task-1')),
    );

    expect(
      connection.onProgress(request).map((event) => event.progress),
      emitsInOrder(<num>[0, 100]),
    );

    final result = await connection.callTool(request);
    expect(result.isError, isNot(true));

    await environment.shutdown();
  });
}

final class _ProtocolTestEnvironment {
  _ProtocolTestEnvironment({required List<CockpitMcpTool> tools})
      : _client =
            MCPClient(Implementation(name: 'test client', version: '1.0.0')),
        _clientController = StreamController<String>(),
        _serverController = StreamController<String>() {
    final clientChannel = StreamChannel<String>.withCloseGuarantee(
      _serverController.stream,
      _clientController.sink,
    );
    final serverChannel = StreamChannel<String>.withCloseGuarantee(
      _clientController.stream,
      _serverController.sink,
    );
    _server = CockpitMcpServer(
      tools: tools,
      serverName: 'flutter_cockpit_devtools',
      serverVersion: '1.0.0',
    ).createProtocolServer(serverChannel);
    _connection = _client.connectServer(clientChannel);
  }

  final MCPClient _client;
  final StreamController<String> _clientController;
  final StreamController<String> _serverController;
  late final MCPServer _server;
  late final ServerConnection _connection;

  Future<ServerConnection> initialize() async {
    final result = await _connection.initialize(
      InitializeRequest(
        protocolVersion: ProtocolVersion.latestSupported,
        capabilities: _client.capabilities,
        clientInfo: _client.implementation,
      ),
    );
    expect(result.serverInfo.name, 'flutter_cockpit_devtools');
    _connection.notifyInitialized(InitializedNotification());
    await _server.initialized;
    return _connection;
  }

  Future<void> shutdown() async {
    await _client.shutdown();
    await _server.shutdown();
  }
}

final class _FakeCockpitMcpTool extends CockpitMcpTool {
  _FakeCockpitMcpTool({
    required this.name,
    this.annotations = CockpitMcpToolAnnotations.defaults,
    this.resultDelay = Duration.zero,
  });

  @override
  final String name;

  @override
  final CockpitMcpToolAnnotations annotations;

  final Duration resultDelay;

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.execution,
      ];

  @override
  String get description => 'fake';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'value': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    if (resultDelay > Duration.zero) {
      await Future<void>.delayed(resultDelay);
    }
    final value = arguments['value'] as String?;
    return cockpitMcpResult(
      text: value ?? 'ok',
      structuredContent: <String, Object?>{'echoedValue': value ?? 'ok'},
    );
  }
}
