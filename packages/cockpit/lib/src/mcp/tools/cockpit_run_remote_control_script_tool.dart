import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_app_reference_resolver.dart';
import '../../application/cockpit_run_remote_control_script_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../../cli/cockpit_control_script.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunRemoteControlScriptFunction =
    Future<CockpitRunRemoteControlScriptResult> Function(
      CockpitRunRemoteControlScriptRequest request,
    );

final class CockpitRunRemoteControlScriptTool extends CockpitMcpTool {
  CockpitRunRemoteControlScriptTool({
    CockpitRunRemoteControlScriptService? service,
    CockpitSessionRegistry? registry,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitRunRemoteControlScriptFunction? run,
  }) : _run = run ?? (service ?? CockpitRunRemoteControlScriptService()).run,
       _appReferenceResolver =
           appReferenceResolver ??
           CockpitAppReferenceResolver(registry: registry);

  final CockpitRunRemoteControlScriptFunction _run;
  final CockpitAppReferenceResolver _appReferenceResolver;

  @override
  String get name => 'run_script';

  @override
  String get description =>
      'Execute a structured flutter_cockpit control script and write a task-run bundle.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'required': <String>['script', 'outputRoot'],
    'properties': <String, Object?>{
      'appId': <String, Object?>{'type': 'string'},
      'appJson': <String, Object?>{'type': 'string'},
      'baseUrl': <String, Object?>{'type': 'string'},
      'androidDeviceId': <String, Object?>{'type': 'string'},
      'iosDeviceId': <String, Object?>{'type': 'string'},
      'platform': <String, Object?>{
        'type': 'string',
        'enum': cockpitControlScriptSupportedPlatforms,
        'description':
            'Optional override for script.platform when reusing one script across platforms.',
      },
      'script': <String, Object?>{'type': 'object'},
      'outputRoot': <String, Object?>{'type': 'string'},
      'persistScriptPath': <String, Object?>{'type': 'string'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final scriptJson = cockpitReadRequiredObject(arguments, 'script');
      late final CockpitControlScript script;
      try {
        final decodedScript = CockpitControlScript.fromJson(scriptJson);
        final platformOverride = _readPlatformOverride(arguments);
        script = platformOverride == null || platformOverride.isEmpty
            ? decodedScript
            : decodedScript.withPlatform(platformOverride);
      } on FormatException catch (error) {
        throw CockpitMcpError.invalidArguments(
          error.message,
          details: <String, Object?>{
            'serviceCode': 'script_invalid',
            'argument': 'script',
          },
        );
      }

      final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
      final resolved = await _appReferenceResolver.resolve(
        appId: cockpitReadOptionalString(arguments, 'appId'),
        appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
        baseUri: baseUrl == null ? null : Uri.parse(baseUrl),
        androidDeviceId: cockpitReadOptionalString(
          arguments,
          'androidDeviceId',
        ),
        iosDeviceId: cockpitReadOptionalString(arguments, 'iosDeviceId'),
      );
      final result = await _run(
        CockpitRunRemoteControlScriptRequest(
          platformAppId:
              resolved.app?.platformAppId ??
              resolved
                  .developmentRecord
                  ?.handle
                  .remoteSessionHandle
                  ?.effectivePlatformAppId ??
              resolved.remoteRecord?.handle.effectivePlatformAppId,
          processId:
              resolved.app?.processId ??
              resolved
                  .developmentRecord
                  ?.handle
                  .remoteSessionHandle
                  ?.processId ??
              resolved.remoteRecord?.handle.processId,
          baseUri: resolved.baseUri,
          sessionHandle:
              resolved.app?.remoteSession ??
              resolved.developmentRecord?.handle.remoteSessionHandle ??
              resolved.remoteRecord?.handle,
          androidDeviceId:
              cockpitReadOptionalString(arguments, 'androidDeviceId') ??
              (resolved.app?.platform == 'android'
                  ? resolved.app?.deviceId
                  : null),
          iosDeviceId:
              cockpitReadOptionalString(arguments, 'iosDeviceId') ??
              (resolved.app?.platform == 'ios' ? resolved.app?.deviceId : null),
          portForwardingHandled: true,
          script: script,
          outputRoot: cockpitReadRequiredString(arguments, 'outputRoot'),
          persistScriptPath: cockpitReadOptionalString(
            arguments,
            'persistScriptPath',
          ),
        ),
      );
      if (result.manifest.status == CockpitTaskStatus.failed) {
        throw CockpitMcpError.internal(
          'Control script bundle failed.',
          details: <String, Object?>{
            'bundleDir': result.bundleDir.path,
            'failureSummary':
                result.manifest.failureSummary ?? 'Unknown failure.',
          },
        );
      }

      return cockpitMcpResult(
        text: 'Remote control script executed and bundle written.',
        structuredContent: <String, Object?>{
          'bundleDir': result.bundleDir.path,
          'manifest': result.manifest.toJson(),
          'handoff': result.handoff,
          'delivery': result.delivery,
          'artifactPaths': result.artifactPaths.toJson(),
          'sessionHandle': result.sessionHandle?.toJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  String? _readPlatformOverride(Map<String, Object?> arguments) {
    final platform = cockpitReadOptionalString(arguments, 'platform');
    if (platform == null) {
      return null;
    }
    if (cockpitControlScriptSupportedPlatforms.contains(platform)) {
      return platform;
    }
    throw CockpitMcpError.invalidArguments(
      'Unsupported platform override.',
      details: <String, Object?>{
        'argument': 'platform',
        'allowed': cockpitControlScriptSupportedPlatforms,
      },
    );
  }
}
