import 'dart:async';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_prompt.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_prompt_definition.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_resource.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_resource_definition.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test('typed protocol server lists and calls cockpit tools', () async {
    final environment = _ProtocolTestEnvironment(
      tools: <CockpitMcpTool>[_FakeCockpitMcpTool(name: 'echo_tool')],
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

  test(
    'typed protocol server emits generic progress for long-running tools',
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
    },
  );

  test('typed protocol server lists and reads resources and prompts', () async {
    final environment = _ProtocolTestEnvironment(
      tools: <CockpitMcpTool>[_FakeCockpitMcpTool(name: 'echo_tool')],
      resources: <CockpitMcpResource>[
        _FakeCockpitMcpResource(
          definition: const CockpitMcpResourceDefinition.fixed(
            name: 'workspace_skill_contract',
            uri: 'cockpit://workspace/skill-contract',
            description: 'Skill contract.',
            mimeType: 'text/markdown',
          ),
          text: '# Skill Contract',
        ),
        _FakeCockpitMcpResource(
          definition: const CockpitMcpResourceDefinition.template(
            name: 'task_summary',
            uriTemplate: 'cockpit://task/summary{?bundleDir}',
            description: 'Task summary.',
            mimeType: 'application/json',
          ),
          text: '{"ok":true}',
        ),
      ],
      prompts: <CockpitMcpPrompt>[
        _FakeCockpitMcpPrompt(name: 'run_closed_loop_task'),
      ],
    );

    final connection = await environment.initialize();

    final resources = await connection.listResources();
    expect(resources.resources.map((resource) => resource.uri), <String>[
      'cockpit://workspace/skill-contract',
    ]);

    final templates = await connection.listResourceTemplates();
    expect(
      templates.resourceTemplates.map((template) => template.uriTemplate),
      <String>['cockpit://task/summary{?bundleDir}'],
    );

    final resourceResult = await connection.readResource(
      ReadResourceRequest(uri: 'cockpit://workspace/skill-contract'),
    );
    expect(
      resourceResult.contents.single,
      isA<TextResourceContents>().having(
        (content) => content.text,
        'text',
        '# Skill Contract',
      ),
    );

    final prompts = await connection.listPrompts();
    expect(prompts.prompts.map((prompt) => prompt.name), <String>[
      'run_closed_loop_task',
    ]);

    final promptResult = await connection.getPrompt(
      GetPromptRequest(
        name: 'run_closed_loop_task',
        arguments: const <String, Object?>{'taskGoal': 'Ship it'},
      ),
    );
    expect(promptResult.messages, hasLength(1));
    expect(
      promptResult.messages.single.content,
      isA<TextContent>().having(
        (content) => content.text,
        'text',
        contains('Ship it'),
      ),
    );

    await environment.shutdown();
  });
}

final class _ProtocolTestEnvironment {
  _ProtocolTestEnvironment({
    required List<CockpitMcpTool> tools,
    this.resources = const <CockpitMcpResource>[],
    this.prompts = const <CockpitMcpPrompt>[],
  }) : _client = MCPClient(
         Implementation(name: 'test client', version: '1.0.0'),
       ),
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
      resources: resources,
      prompts: prompts,
      serverName: 'flutter_cockpit_devtools',
      serverVersion: '1.0.0',
    ).createProtocolServer(serverChannel);
    _connection = _client.connectServer(clientChannel);
  }

  final MCPClient _client;
  final List<CockpitMcpPrompt> prompts;
  final List<CockpitMcpResource> resources;
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

final class _FakeCockpitMcpResource extends CockpitMcpResource {
  const _FakeCockpitMcpResource({required this.definition, required this.text});

  @override
  final CockpitMcpResourceDefinition definition;

  final String text;

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (!definition.isTemplate && request.uri != definition.uri) {
      return null;
    }

    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class _FakeCockpitMcpPrompt extends CockpitMcpPrompt {
  const _FakeCockpitMcpPrompt({required this.name});

  final String name;

  @override
  CockpitMcpPromptDefinition get definition => const CockpitMcpPromptDefinition(
    name: 'run_closed_loop_task',
    description: 'Guides a closed-loop task.',
    arguments: <CockpitMcpPromptArgument>[
      CockpitMcpPromptArgument(name: 'taskGoal', required: true),
    ],
  );

  @override
  Future<CockpitMcpPromptResult> build(Map<String, Object?> arguments) async {
    return CockpitMcpPromptResult(
      messages: <CockpitMcpPromptMessage>[
        CockpitMcpPromptMessage.user('Run the task: ${arguments['taskGoal']}'),
      ],
    );
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
      const <CockpitMcpFeatureCategory>[CockpitMcpFeatureCategory.execution];

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
