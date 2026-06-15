import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'core/cockpit_mcp_feature_configuration.dart';
import 'cockpit_mcp_server.dart';

final class CockpitMcpServerRuntimeOptions {
  const CockpitMcpServerRuntimeOptions({
    required this.enabledNames,
    required this.disabledNames,
    required this.forceRootsFallback,
    required this.workspaceRoots,
    required this.aiDevelopmentProtocolPath,
    required this.skillContractPath,
    required this.bundleContractPath,
    required this.workflowProtocolPath,
    required this.workflowSchemaPath,
    this.logFilePath,
  });

  final Set<String> enabledNames;
  final Set<String> disabledNames;
  final bool forceRootsFallback;
  final List<String> workspaceRoots;
  final String aiDevelopmentProtocolPath;
  final String skillContractPath;
  final String bundleContractPath;
  final String workflowProtocolPath;
  final String workflowSchemaPath;
  final String? logFilePath;
}

typedef CockpitMcpServerRuntimeFactory =
    CockpitMcpServer Function(CockpitMcpServerRuntimeOptions options);

typedef CockpitMcpServerRuntimeServe =
    Future<void> Function(
      CockpitMcpServer server, {
      Sink<String>? protocolLogSink,
    });

abstract interface class _ClosableStringSink implements Sink<String> {
  @override
  Future<void> close();
}

final class _FileProtocolLogSink implements _ClosableStringSink {
  _FileProtocolLogSink._(this._sink);

  final IOSink _sink;

  static Future<_FileProtocolLogSink> create(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return _FileProtocolLogSink._(
      file.openWrite(mode: FileMode.write, encoding: utf8),
    );
  }

  @override
  void add(String data) {
    _sink.write(data);
  }

  @override
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}

final class CockpitMcpServerRuntime {
  CockpitMcpServerRuntime({
    CockpitMcpServerRuntimeFactory? serverFactory,
    CockpitMcpServerRuntimeServe? serve,
  }) : _serverFactory = serverFactory ?? _defaultFactory,
       _serve = serve ?? _defaultServe;

  final CockpitMcpServerRuntimeFactory _serverFactory;
  final CockpitMcpServerRuntimeServe _serve;

  static ArgParser createArgParser() {
    return ArgParser()
      ..addMultiOption(
        'enable',
        help:
            'Enable specific MCP features or categories. Names are matched against tools, resources, prompts, and categories.',
      )
      ..addMultiOption(
        'disable',
        abbr: 'x',
        help:
            'Disable specific MCP features or categories. Disabled names take precedence over category defaults.',
      )
      ..addFlag(
        'force-roots-fallback',
        defaultsTo: false,
        help:
            'Force fallback roots mode even when the client reports native roots support.',
      )
      ..addMultiOption(
        'workspace-root',
        help:
            'Seed one or more manual workspace roots before the MCP client sends roots. Manual roots merge with client roots.',
      )
      ..addOption(
        'ai-development-protocol-file',
        defaultsTo: 'docs/contracts/ai-development-protocol.md',
        help: 'Path to the AI development protocol document.',
      )
      ..addOption(
        'skill-contract-file',
        defaultsTo: 'docs/contracts/flutter-cockpit-skill-contract.md',
        help: 'Path to the flutter_cockpit skill contract document.',
      )
      ..addOption(
        'bundle-contract-file',
        defaultsTo: 'docs/contracts/task-run-bundle.md',
        help: 'Path to the task bundle contract document.',
      )
      ..addOption(
        'workflow-protocol-file',
        defaultsTo: 'docs/contracts/control-workflow-protocol.md',
        help: 'Path to the control workflow protocol document.',
      )
      ..addOption(
        'workflow-schema-file',
        defaultsTo: 'docs/contracts/control-workflow.schema.json',
        help: 'Path to the control workflow JSON Schema document.',
      )
      ..addOption(
        'log-file',
        help: 'Optional file path for raw MCP protocol logging.',
      );
  }

  static CockpitMcpServerRuntimeOptions optionsFromArgs(ArgResults args) {
    return CockpitMcpServerRuntimeOptions(
      enabledNames: args.multiOption('enable').toSet(),
      disabledNames: args.multiOption('disable').toSet(),
      forceRootsFallback: args['force-roots-fallback'] as bool? ?? false,
      workspaceRoots: List<String>.unmodifiable(
        args.multiOption('workspace-root'),
      ),
      aiDevelopmentProtocolPath:
          args['ai-development-protocol-file'] as String? ??
          'docs/contracts/ai-development-protocol.md',
      skillContractPath:
          args['skill-contract-file'] as String? ??
          'docs/contracts/flutter-cockpit-skill-contract.md',
      bundleContractPath:
          args['bundle-contract-file'] as String? ??
          'docs/contracts/task-run-bundle.md',
      workflowProtocolPath:
          args['workflow-protocol-file'] as String? ??
          'docs/contracts/control-workflow-protocol.md',
      workflowSchemaPath:
          args['workflow-schema-file'] as String? ??
          'docs/contracts/control-workflow.schema.json',
      logFilePath: args['log-file'] as String?,
    );
  }

  Future<void> run(ArgResults args) async {
    final options = optionsFromArgs(args);
    final logSink = options.logFilePath == null
        ? null
        : await _FileProtocolLogSink.create(options.logFilePath!);
    try {
      await _serve(_serverFactory(options), protocolLogSink: logSink);
    } finally {
      await logSink?.close();
    }
  }

  static CockpitMcpServer _defaultFactory(
    CockpitMcpServerRuntimeOptions options,
  ) {
    return CockpitMcpServer.standard(
      featureConfiguration: CockpitMcpFeatureConfiguration(
        enabledNames: options.enabledNames,
        disabledNames: options.disabledNames,
      ),
      forceRootsFallback: options.forceRootsFallback,
      workspaceRoots: options.workspaceRoots,
      aiDevelopmentProtocolPath: options.aiDevelopmentProtocolPath,
      skillContractPath: options.skillContractPath,
      bundleContractPath: options.bundleContractPath,
      workflowProtocolPath: options.workflowProtocolPath,
      workflowSchemaPath: options.workflowSchemaPath,
    );
  }

  static Future<void> _defaultServe(
    CockpitMcpServer server, {
    Sink<String>? protocolLogSink,
  }) {
    return server.serveStdio(protocolLogSink: protocolLogSink);
  }
}
