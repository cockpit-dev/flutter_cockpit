import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;

import '../../supervisor/cockpit_supervisor_api_client.dart';
import '../cockpit_cli_runtime.dart';

final class CockpitServerCommand extends Command<int> {
  CockpitServerCommand(this.runtime);

  final CockpitCliRuntime runtime;

  @override
  String get name => 'server';

  @override
  String get description => 'Read Supervisor server discovery metadata.';

  @override
  Future<int> run() async {
    runtime.success((await (await runtime.client()).server()).toJson());
    return cockpitSuccessExitCode;
  }
}

final class CockpitRootCommand extends Command<int> {
  CockpitRootCommand(this.runtime) {
    addSubcommand(
      CockpitLeafCommand(
        name: 'list',
        description: 'List registered roots.',
        action: (_) async {
          runtime.success(
            (await (await runtime.client()).roots())
                .map((root) => root.toJson())
                .toList(),
          );
          return cockpitSuccessExitCode;
        },
      ),
    );
    addSubcommand(
      CockpitLeafCommand(
        name: 'add',
        description: 'Register a root.',
        configure: (parser) => parser
          ..addOption('path', mandatory: true)
          ..addOption('label'),
        action: (arguments) async {
          final path = p.normalize(p.absolute(arguments.option('path')!));
          final root = await (await runtime.client()).registerRoot(
            CockpitRootRegistration(
              path: await Directory(path).resolveSymbolicLinks(),
              label: arguments.option('label'),
            ),
          );
          runtime.success(root.toJson());
          return cockpitSuccessExitCode;
        },
      ),
    );
    addSubcommand(
      CockpitLeafCommand(
        name: 'remove',
        description: 'Unregister a root.',
        configure: (parser) => parser
          ..addOption('root-id', mandatory: true)
          ..addFlag('force', negatable: false)
          ..addOption('drain-timeout-ms', defaultsTo: '30000'),
        action: (arguments) async {
          final timeout = _integer(arguments, 'drain-timeout-ms');
          final result = await (await runtime.client()).removeRoot(
            arguments.option('root-id')!,
            CockpitRootRemoval(
              force: arguments.flag('force'),
              drainTimeoutMs: timeout,
            ),
          );
          runtime.success(result.toJson());
          return cockpitSuccessExitCode;
        },
      ),
    );
  }

  final CockpitCliRuntime runtime;

  @override
  String get name => 'root';

  @override
  String get description => 'Manage registered project roots.';
}

final class CockpitWorkspaceCommand extends Command<int> {
  CockpitWorkspaceCommand(this.runtime) {
    addSubcommand(
      CockpitLeafCommand(
        name: 'list',
        description: 'List registered workspaces.',
        action: (_) async {
          runtime.success(
            (await (await runtime.client()).workspaces())
                .map((workspace) => workspace.toJson())
                .toList(),
          );
          return cockpitSuccessExitCode;
        },
      ),
    );
    addSubcommand(
      CockpitLeafCommand(
        name: 'register',
        description: 'Register a workspace checkout.',
        configure: (parser) => parser
          ..addOption('root-id', mandatory: true)
          ..addOption('path'),
        action: (arguments) async {
          final requested =
              arguments.option('path') ?? runtime.workingDirectory;
          final canonical = await Directory(
            p.normalize(p.absolute(requested)),
          ).resolveSymbolicLinks();
          final workspace = await (await runtime.client()).registerWorkspace(
            CockpitWorkspaceRegistration(
              rootId: arguments.option('root-id')!,
              path: canonical,
            ),
          );
          runtime.success(workspace.toJson());
          return cockpitSuccessExitCode;
        },
      ),
    );
    addSubcommand(
      CockpitLeafCommand(
        name: 'rebind',
        description: 'Rebind a workspace to a checkout.',
        configure: (parser) => parser
          ..addOption('workspace-id', mandatory: true)
          ..addOption('path', mandatory: true)
          ..addOption('expected-checkout-id', mandatory: true),
        action: (arguments) async {
          final path = await Directory(
            p.normalize(p.absolute(arguments.option('path')!)),
          ).resolveSymbolicLinks();
          final workspace = await (await runtime.client()).rebindWorkspace(
            arguments.option('workspace-id')!,
            CockpitWorkspaceRebind(
              path: path,
              expectedCheckoutId: arguments.option('expected-checkout-id')!,
            ),
          );
          runtime.success(workspace.toJson());
          return cockpitSuccessExitCode;
        },
      ),
    );
    addSubcommand(
      CockpitLeafCommand(
        name: 'unregister',
        description: 'Unregister a workspace.',
        configure: (parser) => parser
          ..addOption('workspace-id', mandatory: true)
          ..addFlag('force', negatable: false)
          ..addOption('drain-timeout-ms', defaultsTo: '30000'),
        action: (arguments) async {
          final result = await (await runtime.client()).removeWorkspace(
            arguments.option('workspace-id')!,
            CockpitWorkspaceRemoval(
              force: arguments.flag('force'),
              drainTimeoutMs: _integer(arguments, 'drain-timeout-ms'),
            ),
          );
          runtime.success(result.toJson());
          return cockpitSuccessExitCode;
        },
      ),
    );
  }

  final CockpitCliRuntime runtime;

  @override
  String get name => 'workspace';

  @override
  String get description => 'Manage registered workspace checkouts.';
}

final class CockpitOperationCommand extends Command<int> {
  CockpitOperationCommand(this.runtime) {
    addSubcommand(
      CockpitLeafCommand(
        name: 'list',
        description: 'List advertised operations.',
        configure: (parser) => parser
          ..addOption(
            'scope',
            allowed: const <String>['supervisor', 'workspace'],
            defaultsTo: 'workspace',
          )
          ..addOption('workspace-id'),
        action: (arguments) async {
          final workspaceId = arguments.option('scope') == 'workspace'
              ? await runtime.workspaceId(arguments.option('workspace-id'))
              : null;
          final operations = await (await runtime.client()).operations(
            workspaceId: workspaceId,
          );
          runtime.success(
            operations.map((operation) => operation.toJson()).toList(),
          );
          return cockpitSuccessExitCode;
        },
      ),
    );
    addSubcommand(
      CockpitLeafCommand(
        name: 'run',
        description: 'Execute an advertised typed operation.',
        configure: (parser) => parser
          ..addOption('kind', mandatory: true)
          ..addOption('workspace-id')
          ..addOption('root-id')
          ..addOption('input-json')
          ..addOption('input-file')
          ..addOption('idempotency-key')
          ..addOption('deadline'),
        action: (arguments) async {
          final client = await runtime.client();
          final kind = arguments.option('kind')!;
          final global = await client.operations();
          final globalMatch = global
              .where((item) => item.kind == kind)
              .firstOrNull;
          final CockpitOperationDescriptor descriptor;
          String? workspaceId;
          if (globalMatch != null) {
            descriptor = globalMatch;
          } else {
            workspaceId = await runtime.workspaceId(
              arguments.option('workspace-id'),
            );
            final matches = (await client.operations(
              workspaceId: workspaceId,
            )).where((item) => item.kind == kind);
            if (matches.length != 1) {
              throw CockpitSupervisorClientException(
                code: CockpitErrorCode.unsupportedOperation,
                message: 'Operation $kind is not advertised.',
              );
            }
            descriptor = matches.single;
          }
          if (descriptor.scope == CockpitOperationScope.root &&
              arguments.option('root-id') == null) {
            throw const FormatException(
              '--root-id is required for this operation.',
            );
          }
          final result = await client.executeOperation(
            CockpitOperationInvocation(
              kind: kind,
              input: runtime.jsonObject(
                arguments.option('input-json'),
                arguments.option('input-file'),
              ),
              rootId: descriptor.scope == CockpitOperationScope.root
                  ? arguments.option('root-id')
                  : null,
              workspaceId: descriptor.scope == CockpitOperationScope.workspace
                  ? workspaceId
                  : null,
              idempotencyKey: arguments.option('idempotency-key') == null
                  ? null
                  : CockpitIdempotencyKey(arguments.option('idempotency-key')!),
              deadline: arguments.option('deadline') == null
                  ? null
                  : DateTime.parse(arguments.option('deadline')!).toUtc(),
            ),
          );
          runtime.success(result.toJson());
          return cockpitSuccessExitCode;
        },
      ),
    );
  }

  final CockpitCliRuntime runtime;

  @override
  String get name => 'operation';

  @override
  String get description => 'Inspect and execute advertised operations.';
}

int _integer(ArgResults arguments, String name) {
  final value = int.tryParse(arguments.option(name)!);
  if (value == null) throw FormatException('--$name is invalid.');
  return value;
}
