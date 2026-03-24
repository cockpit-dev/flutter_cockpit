import 'package:collection/collection.dart';

import '../runtime/cockpit_snapshot_options.dart';
import 'cockpit_capture_policy.dart';
import 'cockpit_command_type.dart';
import 'cockpit_locator.dart';
import 'cockpit_screenshot_request.dart';

final class CockpitCommand {
  CockpitCommand({
    required this.commandId,
    required this.commandType,
    this.locator,
    Map<String, Object?> parameters = const <String, Object?>{},
    this.capturePolicy = CockpitCapturePolicy.none,
    this.timeoutMs,
    this.snapshotOptions,
    this.screenshotRequest,
  }) : parameters = Map.unmodifiable(parameters);

  final String commandId;
  final CockpitCommandType commandType;
  final CockpitLocator? locator;
  final Map<String, Object?> parameters;
  final CockpitCapturePolicy capturePolicy;
  final int? timeoutMs;
  final CockpitSnapshotOptions? snapshotOptions;
  final CockpitScreenshotRequest? screenshotRequest;

  static const MapEquality<String, Object?> _mapEquality =
      MapEquality<String, Object?>();

  Map<String, Object?> toJson() => {
        'commandId': commandId,
        'commandType': commandType.name,
        'locator': locator?.toJson(),
        'parameters': parameters,
        'capturePolicy': capturePolicy.name,
        'timeoutMs': timeoutMs,
        'snapshotOptions': snapshotOptions?.toJson(),
        'screenshotRequest': screenshotRequest?.toJson(),
      };

  factory CockpitCommand.fromJson(Map<String, Object?> json) {
    final locatorJson = json['locator'] as Map<Object?, Object?>?;
    final snapshotOptionsJson =
        json['snapshotOptions'] as Map<Object?, Object?>?;
    final screenshotRequestJson =
        json['screenshotRequest'] as Map<Object?, Object?>?;

    return CockpitCommand(
      commandId: json['commandId']! as String,
      commandType: CockpitCommandType.fromJson(json['commandType']),
      locator: locatorJson == null
          ? null
          : CockpitLocator.fromJson(Map<String, Object?>.from(locatorJson)),
      parameters: Map<String, Object?>.from(
        (json['parameters'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{},
      ),
      capturePolicy: json['capturePolicy'] == null
          ? CockpitCapturePolicy.none
          : CockpitCapturePolicy.fromJson(json['capturePolicy']),
      timeoutMs: json['timeoutMs'] as int?,
      snapshotOptions: snapshotOptionsJson == null
          ? null
          : CockpitSnapshotOptions.fromJson(
              Map<String, Object?>.from(snapshotOptionsJson),
            ),
      screenshotRequest: screenshotRequestJson == null
          ? null
          : CockpitScreenshotRequest.fromJson(
              Map<String, Object?>.from(screenshotRequestJson),
            ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitCommand &&
            other.commandId == commandId &&
            other.commandType == commandType &&
            other.locator == locator &&
            _mapEquality.equals(other.parameters, parameters) &&
            other.capturePolicy == capturePolicy &&
            other.timeoutMs == timeoutMs &&
            other.snapshotOptions == snapshotOptions &&
            other.screenshotRequest == screenshotRequest;
  }

  @override
  int get hashCode => Object.hash(
        commandId,
        commandType,
        locator,
        _mapEquality.hash(parameters),
        capturePolicy,
        timeoutMs,
        snapshotOptions,
        screenshotRequest,
      );
}
