import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_execute_remote_command_batch_service.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_session_registry.dart';

typedef CockpitRunBatchCommand = CockpitInteractiveBatchCommand;

final class CockpitRunBatchRequest {
  const CockpitRunBatchRequest({
    required this.commands,
    this.appId,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.defaultResultProfile =
        const CockpitInteractiveResultProfile.standard(),
    this.failFast = true,
    this.recording,
    this.finalSnapshotProfile,
    this.finalSnapshotOptions,
    this.defaultCommandTimeout = const Duration(seconds: 4),
  });

  final List<CockpitRunBatchCommand> commands;
  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile defaultResultProfile;
  final bool failFast;
  final CockpitRecordingRequest? recording;
  final CockpitInteractiveResultProfile? finalSnapshotProfile;
  final CockpitSnapshotOptions? finalSnapshotOptions;
  final Duration defaultCommandTimeout;
}

typedef CockpitRunBatchResult = CockpitExecuteRemoteCommandBatchResult;

final class CockpitRunBatchService {
  CockpitRunBatchService({
    CockpitExecuteRemoteCommandBatchService? executeService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  })  : _executeService =
            executeService ?? CockpitExecuteRemoteCommandBatchService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry);

  final CockpitExecuteRemoteCommandBatchService _executeService;
  final CockpitAppReferenceResolver _appReferenceResolver;

  Future<CockpitRunBatchResult> run(CockpitRunBatchRequest request) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
      baseUri: request.baseUri,
      androidDeviceId: request.androidDeviceId,
    );
    return _executeService.execute(
      CockpitExecuteRemoteCommandBatchRequest(
        commands: request.commands,
        baseUri: resolved.baseUri,
        defaultResultProfile: request.defaultResultProfile,
        failFast: request.failFast,
        recording: request.recording,
        finalSnapshotProfile: request.finalSnapshotProfile,
        finalSnapshotOptions: request.finalSnapshotOptions,
        defaultCommandTimeout: request.defaultCommandTimeout,
      ),
    );
  }
}
