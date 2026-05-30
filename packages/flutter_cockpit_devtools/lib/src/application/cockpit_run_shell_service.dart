import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../infrastructure/cockpit_process_manager.dart';
import '../platform/cockpit_platform_driver_registry.dart';
import '../targets/cockpit_target_capability_support.dart';
import '../targets/cockpit_target_handle.dart';
import '../targets/cockpit_target_reference_resolver.dart';
import 'cockpit_application_service_exception.dart';

final class CockpitRunShellRequest {
  const CockpitRunShellRequest({
    required this.command,
    this.scope = 'host',
    this.workingDirectory,
    this.target,
    this.targetHandlePath,
    this.deviceId,
    this.timeout = const Duration(seconds: 30),
  });

  final List<String> command;
  final String scope;
  final String? workingDirectory;
  final CockpitTargetHandle? target;
  final String? targetHandlePath;
  final String? deviceId;
  final Duration timeout;
}

final class CockpitRunShellResult {
  const CockpitRunShellResult({
    required this.scope,
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.success,
    required this.recommendedNextStep,
  });

  final String scope;
  final List<String> command;
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool success;
  final String recommendedNextStep;

  Map<String, Object?> toJson() => <String, Object?>{
    'scope': scope,
    'command': command,
    'exitCode': exitCode,
    'stdout': stdout,
    'stderr': stderr,
    'success': success,
    'recommendedNextStep': recommendedNextStep,
  };
}

typedef CockpitRunShellFunction =
    Future<CockpitRunShellResult> Function(CockpitRunShellRequest request);

final class CockpitRunShellService {
  CockpitRunShellService({
    CockpitRunShellFunction? runShell,
    CockpitProcessManager? processManager,
    CockpitTargetReferenceResolver? targetReferenceResolver,
    CockpitPlatformDriverRegistry? platformDriverRegistry,
  }) : _runShellOverride = runShell,
       _processManager = processManager ?? const LocalCockpitProcessManager(),
       _targetReferenceResolver =
           targetReferenceResolver ?? CockpitTargetReferenceResolver(),
       _platformDriverRegistry =
           platformDriverRegistry ?? CockpitPlatformDriverRegistry();

  final CockpitRunShellFunction? _runShellOverride;
  final CockpitProcessManager _processManager;
  final CockpitTargetReferenceResolver _targetReferenceResolver;
  final CockpitPlatformDriverRegistry _platformDriverRegistry;

  Future<CockpitRunShellResult> run(CockpitRunShellRequest request) async {
    final override = _runShellOverride;
    if (override != null) {
      return override(request);
    }

    if (request.command.isEmpty) {
      throw ArgumentError.value(
        request.command,
        'command',
        'run-shell requires a non-empty command.',
      );
    }

    final execution = await _resolveExecution(request);
    final ProcessResult result;
    try {
      result = await cockpitRunManagedProcessWithTimeout(
        _processManager,
        execution.executable,
        execution.arguments,
        workingDirectory: request.workingDirectory,
        timeout: request.timeout,
      );
    } on CockpitManagedProcessTimeoutException catch (error) {
      throw CockpitApplicationServiceException(
        code: 'shellCommandTimedOut',
        message: 'Shell command timed out.',
        details: <String, Object?>{
          'scope': execution.scope,
          'command': execution.command,
          'timeoutMs': request.timeout.inMilliseconds,
          if (error.stdout.trim().isNotEmpty)
            'stdoutPreview': _outputPreview(error.stdout),
          if (error.stderr.trim().isNotEmpty)
            'stderrPreview': _outputPreview(error.stderr),
        },
      );
    } on TimeoutException catch (error) {
      throw CockpitApplicationServiceException(
        code: 'shellCommandTimedOut',
        message: 'Shell command timed out.',
        details: <String, Object?>{
          'scope': execution.scope,
          'command': execution.command,
          'timeoutMs': (error.duration ?? request.timeout).inMilliseconds,
        },
      );
    }
    final stdoutText = '${result.stdout}'.trimRight();
    final stderrText = '${result.stderr}'.trimRight();
    final success = result.exitCode == 0;
    return CockpitRunShellResult(
      scope: execution.scope,
      command: execution.command,
      exitCode: result.exitCode,
      stdout: stdoutText,
      stderr: stderrText,
      success: success,
      recommendedNextStep: success ? 'continue' : 'inspectShellFailure',
    );
  }

  Future<_ResolvedShellExecution> _resolveExecution(
    CockpitRunShellRequest request,
  ) async {
    if (request.scope == 'host') {
      return _ResolvedShellExecution.host(
        scope: 'host',
        command: request.command,
      );
    }

    final referencedTarget = await _resolveOptionalTarget(request);
    if (request.scope == 'target') {
      if (referencedTarget == null) {
        throw const CockpitApplicationServiceException(
          code: 'missingTargetReference',
          message: 'run-shell with target scope requires a target handle.',
        );
      }
      return _resolvePlatformExecution(
        scope: referencedTarget.platform,
        command: request.command,
        deviceId: referencedTarget.deviceId,
      );
    }

    if (referencedTarget != null &&
        referencedTarget.platform != request.scope) {
      throw CockpitApplicationServiceException(
        code: 'targetScopeMismatch',
        message: 'The provided target handle does not match the shell scope.',
        details: <String, Object?>{
          'scope': request.scope,
          'targetPlatform': referencedTarget.platform,
        },
      );
    }

    return _resolvePlatformExecution(
      scope: request.scope,
      command: request.command,
      deviceId: request.deviceId ?? referencedTarget?.deviceId,
    );
  }

  Future<CockpitTargetHandle?> _resolveOptionalTarget(
    CockpitRunShellRequest request,
  ) async {
    if (request.target == null &&
        (request.targetHandlePath == null ||
            request.targetHandlePath!.isEmpty)) {
      return null;
    }
    final resolved = await _targetReferenceResolver.resolve(
      target: request.target,
      targetHandlePath: request.targetHandlePath,
    );
    return resolved.target;
  }

  Future<_ResolvedShellExecution> _resolvePlatformExecution({
    required String scope,
    required List<String> command,
    required String? deviceId,
  }) async {
    final normalizedDeviceId = deviceId ?? _defaultDeviceIdForScope(scope);
    if (normalizedDeviceId == null || normalizedDeviceId.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'missingDeviceId',
        message: 'run-shell requires a device ID for this scope.',
        details: <String, Object?>{'scope': scope},
      );
    }

    final driver = _platformDriverRegistry.resolve(
      platform: scope,
      deviceId: normalizedDeviceId,
    );
    if (driver == null) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedPlatform',
        message: 'run-shell does not support this platform.',
        details: <String, Object?>{'platform': scope},
      );
    }

    final capabilityProfile = await driver.describeCapabilities();
    if (!capabilityProfile.supportsAction(CockpitActionCapability.runShell)) {
      throw CockpitApplicationServiceException(
        code: 'unsupportedShellScope',
        message: 'run-shell is not available for this target scope.',
        details: <String, Object?>{
          'scope': scope,
          'platform': scope,
          'recommendedNextStep': cockpitRecommendedNextStepForProfile(
            capabilityProfile,
          ),
        },
      );
    }

    return switch (scope) {
      'android' => _ResolvedShellExecution(
        scope: 'android',
        executable: 'adb',
        arguments: <String>['-s', normalizedDeviceId, 'shell', ...command],
        command: command,
      ),
      'ios' => _ResolvedShellExecution(
        scope: 'ios',
        executable: 'xcrun',
        arguments: <String>['simctl', 'spawn', normalizedDeviceId, ...command],
        command: command,
      ),
      'macos' ||
      'windows' ||
      'linux' ||
      'web' => _ResolvedShellExecution.host(scope: scope, command: command),
      _ => throw CockpitApplicationServiceException(
        code: 'unsupportedPlatform',
        message: 'run-shell does not support this platform.',
        details: <String, Object?>{'platform': scope},
      ),
    };
  }

  String? _defaultDeviceIdForScope(String scope) {
    return switch (scope) {
      'macos' => 'macos',
      'windows' => 'windows',
      'linux' => 'linux',
      'web' => 'web',
      _ => null,
    };
  }
}

String _outputPreview(String output, {int maxChars = 800}) {
  final normalized = output.trim();
  if (normalized.length <= maxChars) {
    return normalized;
  }
  return '${normalized.substring(0, maxChars).trimRight()}...';
}

final class _ResolvedShellExecution {
  const _ResolvedShellExecution({
    required this.scope,
    required this.executable,
    required this.arguments,
    required this.command,
  });

  factory _ResolvedShellExecution.host({
    required String scope,
    required List<String> command,
  }) {
    return _ResolvedShellExecution(
      scope: scope,
      executable: command.first,
      arguments: command.skip(1).toList(growable: false),
      command: List<String>.unmodifiable(command),
    );
  }

  final String scope;
  final String executable;
  final List<String> arguments;
  final List<String> command;
}
