import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../application/cockpit_capture_screenshot_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitCaptureScreenshotToolFunction =
    Future<CockpitCaptureScreenshotResult> Function(
      CockpitCaptureScreenshotRequest request,
    );

final class CockpitCaptureScreenshotTool extends CockpitMcpTool {
  CockpitCaptureScreenshotTool({
    CockpitCaptureScreenshotService? service,
    CockpitCaptureScreenshotToolFunction? capture,
  }) : _capture =
           capture ?? (service ?? CockpitCaptureScreenshotService()).capture;

  final CockpitCaptureScreenshotToolFunction _capture;

  @override
  String get name => 'capture_screenshot';

  @override
  String get description =>
      'Capture one named screenshot from a running app without constructing a generic command payload.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'appId': <String, Object?>{'type': 'string'},
      'appJson': <String, Object?>{'type': 'string'},
      'baseUrl': <String, Object?>{'type': 'string'},
      'androidDeviceId': <String, Object?>{'type': 'string'},
      'iosDeviceId': <String, Object?>{'type': 'string'},
      'name': <String, Object?>{'type': 'string'},
      'reason': <String, Object?>{'type': 'string'},
      'includeSnapshot': <String, Object?>{'type': 'boolean'},
      'attachToStep': <String, Object?>{'type': 'boolean'},
      'timeoutMs': <String, Object?>{'type': 'integer'},
      'profile': <String, Object?>{'type': 'string'},
    },
  };

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.execution,
        CockpitMcpFeatureCategory.inspection,
      ];

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
    readOnly: false,
    destructive: false,
    idempotent: false,
    longRunning: false,
    requiresSession: false,
    producesBundleEvidence: false,
  );

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _capture(
        CockpitCaptureScreenshotRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: _readOptionalBaseUri(arguments),
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          iosDeviceId: cockpitReadOptionalString(arguments, 'iosDeviceId'),
          name: cockpitReadOptionalString(arguments, 'name') ?? 'screenshot',
          reason: _readReason(arguments),
          includeSnapshot:
              cockpitReadOptionalBool(arguments, 'includeSnapshot') ?? false,
          attachToStep:
              cockpitReadOptionalBool(arguments, 'attachToStep') ?? true,
          defaultCommandTimeout: Duration(
            milliseconds:
                cockpitReadOptionalPositiveInt(arguments, 'timeoutMs') ?? 30000,
          ),
          resultProfile: _readProfile(arguments),
        ),
      );
      return cockpitMcpResult(
        text: 'Screenshot captured.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitScreenshotReason _readReason(Map<String, Object?> arguments) {
    return CockpitScreenshotReason.fromJson(
      cockpitReadOptionalString(arguments, 'reason') ??
          CockpitScreenshotReason.acceptance.jsonValue,
    );
  }

  CockpitInteractiveResultProfile _readProfile(Map<String, Object?> arguments) {
    final value = arguments['profile'];
    if (value == null) {
      return const CockpitInteractiveResultProfile.standard();
    }
    return CockpitInteractiveResultProfile.preset(
      CockpitInteractiveResultProfileName.fromJson(value),
    );
  }

  Uri? _readOptionalBaseUri(Map<String, Object?> arguments) {
    final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}
