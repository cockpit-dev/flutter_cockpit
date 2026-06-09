import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cockpit_system_control_action.dart';
import 'cockpit_system_control_adapter.dart';

const String cockpitIosWdaCommandExecutable =
    '__flutter_cockpit_ios_webdriver_agent';

typedef CockpitIosWdaHttpClientFactory = http.Client Function();
typedef CockpitIosWdaEndpointProbe =
    Future<bool> Function(Uri baseUri, {required Duration timeout});

Future<bool> cockpitProbeIosWdaEndpoint(
  Uri baseUri, {
  required Duration timeout,
}) async {
  try {
    await CockpitIosWebDriverAgentClient().ping(baseUri, timeout: timeout);
    return true;
  } on Object {
    return false;
  }
}

final class CockpitIosWebDriverAgentClient {
  CockpitIosWebDriverAgentClient({
    http.Client? httpClient,
    CockpitIosWdaHttpClientFactory? httpClientFactory,
  }) : _httpClient = httpClient,
       _httpClientFactory = httpClientFactory ?? http.Client.new;

  final http.Client? _httpClient;
  final CockpitIosWdaHttpClientFactory _httpClientFactory;

  Future<void> ping(Uri baseUri, {required Duration timeout}) {
    return _withClient((client) async {
      final response = await client
          .get(_resolve(baseUri, '/status'))
          .timeout(timeout);
      _ensureSuccess(response, 'read WebDriverAgent status');
      _decodeObject(response.body);
    });
  }

  Future<CockpitIosWdaSession> resolveSession(
    Uri baseUri, {
    required Duration timeout,
  }) async {
    return _withClient((client) async {
      final response = await client
          .get(_resolve(baseUri, '/status'))
          .timeout(timeout);
      _ensureSuccess(response, 'read WebDriverAgent status');
      final decoded = _decodeObject(response.body);
      final resolvedSessionId =
          _readNestedString(decoded, const <String>['sessionId']) ??
          _readNestedString(decoded, const <String>['value', 'sessionId']);
      if (resolvedSessionId == null || resolvedSessionId.trim().isEmpty) {
        return _createSession(client, baseUri, timeout: timeout);
      }
      return CockpitIosWdaSession(
        baseUri: baseUri,
        sessionId: resolvedSessionId.trim(),
      );
    });
  }

  Future<CockpitIosWdaSession> _createSession(
    http.Client client,
    Uri baseUri, {
    required Duration timeout,
  }) async {
    final response = await client
        .post(
          _resolve(baseUri, '/session'),
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(<String, Object?>{
            'capabilities': <String, Object?>{
              'alwaysMatch': <String, Object?>{},
            },
            'desiredCapabilities': <String, Object?>{},
          }),
        )
        .timeout(timeout);
    _ensureSuccess(response, 'create WebDriverAgent session');
    final decoded = _decodeObject(response.body);
    final resolvedSessionId =
        _readNestedString(decoded, const <String>['sessionId']) ??
        _readNestedString(decoded, const <String>['value', 'sessionId']);
    if (resolvedSessionId == null || resolvedSessionId.trim().isEmpty) {
      throw StateError(
        'WebDriverAgent session creation did not return a session id.',
      );
    }
    return CockpitIosWdaSession(
      baseUri: baseUri,
      sessionId: resolvedSessionId.trim(),
    );
  }

  static CockpitIosWdaCommand commandFromArguments(List<String> arguments) {
    if (arguments.length != 1) {
      throw ArgumentError.value(
        arguments,
        'arguments',
        'WebDriverAgent internal command requires one JSON argument.',
      );
    }
    final decoded = jsonDecode(arguments.single);
    if (decoded is! Map<Object?, Object?>) {
      throw ArgumentError.value(
        arguments.single,
        'arguments',
        'WebDriverAgent internal command JSON must be an object.',
      );
    }
    final json = decoded.cast<String, Object?>();
    return CockpitIosWdaCommand(
      baseUri: Uri.parse(json['baseUrl']! as String),
      action: CockpitIosWdaAction.values.byName(json['action']! as String),
      parameters:
          (json['parameters'] as Map<Object?, Object?>?)
              ?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
  }

  static List<String> commandToArguments(CockpitIosWdaCommand command) {
    return <String>[
      jsonEncode(<String, Object?>{
        'baseUrl': command.baseUri.toString(),
        'action': command.action.name,
        if (command.parameters.isNotEmpty) 'parameters': command.parameters,
      }),
    ];
  }

  static CockpitResolvedSystemControlCommand resolvedCommand(
    CockpitIosWdaCommand command,
  ) {
    return CockpitResolvedSystemControlCommand(
      cockpitIosWdaCommandExecutable,
      commandToArguments(command),
    );
  }

  Future<String> run(
    CockpitIosWdaCommand command, {
    required Duration timeout,
  }) async {
    final session = await resolveSession(command.baseUri, timeout: timeout);
    return _withClient((client) async {
      switch (command.action) {
        case CockpitIosWdaAction.tap:
          final x = _requiredInt(command.parameters, 'x');
          final y = _requiredInt(command.parameters, 'y');
          await _postSession(client, session, 'actions', <String, Object?>{
            'actions': <Object?>[
              <String, Object?>{
                'type': 'pointer',
                'id': 'cockpit-finger',
                'parameters': <String, Object?>{'pointerType': 'touch'},
                'actions': <Object?>[
                  <String, Object?>{
                    'type': 'pointerMove',
                    'duration': 0,
                    'origin': 'viewport',
                    'x': x,
                    'y': y,
                  },
                  <String, Object?>{'type': 'pointerDown', 'button': 0},
                  <String, Object?>{'type': 'pointerUp', 'button': 0},
                ],
              },
            ],
          }, timeout: timeout);
          return 'tap x=$x y=$y';
        case CockpitIosWdaAction.longPress:
          final x = _requiredInt(command.parameters, 'x');
          final y = _requiredInt(command.parameters, 'y');
          final durationMs =
              _optionalPositiveInt(command.parameters, 'durationMs') ?? 800;
          await _postSession(client, session, 'actions', <String, Object?>{
            'actions': <Object?>[
              <String, Object?>{
                'type': 'pointer',
                'id': 'cockpit-finger',
                'parameters': <String, Object?>{'pointerType': 'touch'},
                'actions': <Object?>[
                  <String, Object?>{
                    'type': 'pointerMove',
                    'duration': 0,
                    'origin': 'viewport',
                    'x': x,
                    'y': y,
                  },
                  <String, Object?>{'type': 'pointerDown', 'button': 0},
                  <String, Object?>{'type': 'pause', 'duration': durationMs},
                  <String, Object?>{'type': 'pointerUp', 'button': 0},
                ],
              },
            ],
          }, timeout: timeout);
          return 'longPress x=$x y=$y durationMs=$durationMs';
        case CockpitIosWdaAction.drag:
          final startX = _requiredInt(command.parameters, 'startX');
          final startY = _requiredInt(command.parameters, 'startY');
          final endX = _requiredInt(command.parameters, 'endX');
          final endY = _requiredInt(command.parameters, 'endY');
          final durationMs =
              _optionalPositiveInt(command.parameters, 'durationMs') ?? 300;
          await _postSession(client, session, 'actions', <String, Object?>{
            'actions': <Object?>[
              <String, Object?>{
                'type': 'pointer',
                'id': 'cockpit-finger',
                'parameters': <String, Object?>{'pointerType': 'touch'},
                'actions': <Object?>[
                  <String, Object?>{
                    'type': 'pointerMove',
                    'duration': 0,
                    'origin': 'viewport',
                    'x': startX,
                    'y': startY,
                  },
                  <String, Object?>{'type': 'pointerDown', 'button': 0},
                  <String, Object?>{
                    'type': 'pointerMove',
                    'duration': durationMs,
                    'origin': 'viewport',
                    'x': endX,
                    'y': endY,
                  },
                  <String, Object?>{'type': 'pointerUp', 'button': 0},
                ],
              },
            ],
          }, timeout: timeout);
          return 'drag start=($startX,$startY) end=($endX,$endY) durationMs=$durationMs';
        case CockpitIosWdaAction.typeText:
          final text = _requiredString(command.parameters, 'text');
          await _postSession(client, session, 'actions', <String, Object?>{
            'actions': <Object?>[
              <String, Object?>{
                'type': 'key',
                'id': 'cockpit-keyboard',
                'actions': _keyboardActions(text),
              },
            ],
          }, timeout: timeout);
          return 'typeText length=${text.length}';
        case CockpitIosWdaAction.pressKey:
          final key = _requiredString(command.parameters, 'key');
          final mapped = _mapKey(key);
          await _postSession(client, session, 'actions', <String, Object?>{
            'actions': <Object?>[
              <String, Object?>{
                'type': 'key',
                'id': 'cockpit-keyboard',
                'actions': <Object?>[
                  <String, Object?>{'type': 'keyDown', 'value': mapped},
                  <String, Object?>{'type': 'keyUp', 'value': mapped},
                ],
              },
            ],
          }, timeout: timeout);
          return 'pressKey key=$key';
        case CockpitIosWdaAction.dismissSystemDialog:
          final mode =
              _optionalString(command.parameters, 'mode') ??
              _optionalString(command.parameters, 'decision') ??
              'accept';
          final endpoint = switch (mode) {
            'dismiss' || 'cancel' || 'deny' => 'alert/dismiss',
            _ => 'alert/accept',
          };
          await _postSession(
            client,
            session,
            endpoint,
            const <String, Object?>{},
            timeout: timeout,
          );
          return 'dismissSystemDialog mode=$mode';
        case CockpitIosWdaAction.dismissKeyboard:
          await _postSession(
            client,
            session,
            'wda/keyboard/dismiss',
            const <String, Object?>{},
            timeout: timeout,
          );
          return 'dismissKeyboard';
        case CockpitIosWdaAction.pressButton:
          final name = _requiredString(command.parameters, 'name');
          final durationMs =
              _optionalPositiveInt(command.parameters, 'durationMs');
          await _postSession(
            client,
            session,
            'wda/pressButton',
            <String, Object?>{
              'name': _mapButtonName(name),
              if (durationMs != null) 'duration': durationMs / 1000.0,
            },
            timeout: timeout,
          );
          return 'pressButton name=$name';
        case CockpitIosWdaAction.pressHome:
          await _postSession(
            client,
            session,
            'wda/homescreen',
            const <String, Object?>{},
            timeout: timeout,
          );
          return 'pressHome';
        case CockpitIosWdaAction.setOrientation:
          final orientation = _requiredString(
            command.parameters,
            'orientation',
          );
          await _postSession(client, session, 'orientation', <String, Object?>{
            'orientation': _mapOrientation(orientation),
          }, timeout: timeout);
          return 'setOrientation orientation=$orientation';
        case CockpitIosWdaAction.readUiTree:
          final response = await _getSession(
            client,
            session,
            'source',
            timeout: timeout,
          );
          final decoded = _decodeObject(response.body);
          final value = decoded['value'];
          return value is String ? value : jsonEncode(value);
        case CockpitIosWdaAction.readDeviceInfo:
          final response = await _getSession(
            client,
            session,
            'wda/device/info',
            timeout: timeout,
          );
          return response.body;
      }
    });
  }

  Future<T> _withClient<T>(Future<T> Function(http.Client client) callback) {
    final ownedClient = _httpClient == null ? _httpClientFactory() : null;
    final client = _httpClient ?? ownedClient!;
    return callback(client).whenComplete(() => ownedClient?.close());
  }

  Future<http.Response> _postSession(
    http.Client client,
    CockpitIosWdaSession session,
    String path,
    Map<String, Object?> payload, {
    required Duration timeout,
  }) async {
    final response = await client
        .post(
          _resolve(
            session.baseUri,
            '/session/${Uri.encodeComponent(session.sessionId)}/$path',
          ),
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    _ensureSuccess(response, 'run WebDriverAgent $path');
    return response;
  }

  Future<http.Response> _getSession(
    http.Client client,
    CockpitIosWdaSession session,
    String path, {
    required Duration timeout,
  }) async {
    final response = await client
        .get(
          _resolve(
            session.baseUri,
            '/session/${Uri.encodeComponent(session.sessionId)}/$path',
          ),
        )
        .timeout(timeout);
    _ensureSuccess(response, 'run WebDriverAgent $path');
    return response;
  }

  Uri _resolve(Uri baseUri, String path) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$basePath$path');
  }

  Map<String, Object?> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<Object?, Object?>) {
      return decoded.cast<String, Object?>();
    }
    throw StateError('WebDriverAgent response was not a JSON object.');
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to $operation: HTTP ${response.statusCode} ${response.body}',
      );
    }
  }

  String? _readNestedString(Map<String, Object?> json, List<String> path) {
    Object? current = json;
    for (final segment in path) {
      if (current is! Map<Object?, Object?>) {
        return null;
      }
      current = current[segment];
    }
    return current is String ? current : null;
  }

  int _requiredInt(Map<String, Object?> parameters, String key) {
    final value = cockpitReadSystemControlIntParameter(parameters, key);
    if (!value.isValid) {
      throw StateError('WebDriverAgent command requires integer $key.');
    }
    return value.value!;
  }

  int? _optionalPositiveInt(Map<String, Object?> parameters, String key) {
    final value = cockpitReadSystemControlIntParameter(
      parameters,
      key,
      minimum: 1,
    );
    if (value.isInvalid) {
      throw StateError(
        'WebDriverAgent command requires positive integer $key.',
      );
    }
    return value.value;
  }

  String _requiredString(Map<String, Object?> parameters, String key) {
    final value = cockpitReadSystemControlStringParameter(parameters, key);
    if (!value.isValid) {
      throw StateError('WebDriverAgent command requires string $key.');
    }
    return value.value!;
  }

  String? _optionalString(Map<String, Object?> parameters, String key) {
    final value = cockpitReadSystemControlStringParameter(parameters, key);
    if (value.isInvalid) {
      throw StateError('WebDriverAgent command requires string $key.');
    }
    return value.value;
  }

  List<Object?> _keyboardActions(String text) {
    return text.runes
        .map(String.fromCharCode)
        .expand(
          (character) => <Object?>[
            <String, Object?>{'type': 'keyDown', 'value': character},
            <String, Object?>{'type': 'keyUp', 'value': character},
          ],
        )
        .toList(growable: false);
  }

  String _mapKey(String key) {
    return switch (key.trim().toLowerCase()) {
      'enter' || 'return' || 'keycode_enter' => '\uE007',
      'tab' || 'keycode_tab' => '\uE004',
      'escape' || 'esc' || 'keycode_escape' => '\uE00C',
      'backspace' || 'delete' || 'keycode_del' => '\uE003',
      _ => key,
    };
  }

  String _mapOrientation(String orientation) {
    return switch (orientation) {
      'landscape' => 'LANDSCAPE',
      'reverseLandscape' => 'UIA_DEVICE_ORIENTATION_LANDSCAPERIGHT',
      'reversePortrait' => 'UIA_DEVICE_ORIENTATION_PORTRAIT_UPSIDEDOWN',
      _ => 'PORTRAIT',
    };
  }

  String _mapButtonName(String name) {
    return switch (name.trim().toLowerCase()) {
      'home' => 'home',
      'volumeup' || 'volume_up' || 'volume-up' => 'volumeUp',
      'volumedown' || 'volume_down' || 'volume-down' => 'volumeDown',
      'action' => 'action',
      'camera' => 'camera',
      _ => name,
    };
  }
}

final class CockpitIosWdaSession {
  const CockpitIosWdaSession({required this.baseUri, required this.sessionId});

  final Uri baseUri;
  final String sessionId;
}

final class CockpitIosWdaCommand {
  const CockpitIosWdaCommand({
    required this.baseUri,
    required this.action,
    this.parameters = const <String, Object?>{},
  });

  final Uri baseUri;
  final CockpitIosWdaAction action;
  final Map<String, Object?> parameters;
}

enum CockpitIosWdaAction {
  tap,
  longPress,
  drag,
  typeText,
  pressKey,
  dismissSystemDialog,
  dismissKeyboard,
  pressButton,
  pressHome,
  setOrientation,
  readUiTree,
  readDeviceInfo,
}
