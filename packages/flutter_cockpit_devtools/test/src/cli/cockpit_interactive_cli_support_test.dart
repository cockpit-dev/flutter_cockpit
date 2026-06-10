import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_interactive_cli_support.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cockpitResolveAppHandlePath ignores the implicit default handle when base-url is explicitly provided',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_cli_support_base_url_precedence',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final defaultHandle = File(cockpitDefaultAppHandlePath(tempDir.path));
      await defaultHandle.parent.create(recursive: true);
      await defaultHandle.writeAsString('{}');

      final parser = ArgParser()
        ..addOption('app-json')
        ..addOption('base-url');
      final argResults = parser.parse(<String>[
        '--base-url',
        'http://127.0.0.1:47331',
      ]);

      expect(
        cockpitResolveAppHandlePath(argResults, workingDirectory: tempDir.path),
        isNull,
      );
    },
  );

  test(
    'cockpitResolveAppHandlePath does not assume every command defines base-url',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_cli_support_no_base_url_option',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final defaultHandle = File(cockpitDefaultAppHandlePath(tempDir.path));
      await defaultHandle.parent.create(recursive: true);
      await defaultHandle.writeAsString('{}');

      final parser = ArgParser()..addOption('app-json');
      final argResults = parser.parse(const <String>[]);

      expect(
        cockpitResolveAppHandlePath(argResults, workingDirectory: tempDir.path),
        defaultHandle.path,
      );
    },
  );

  group('cockpitWriteJsonPayload', () {
    test(
      'defaults stdout to AI full render when no output file is requested',
      () async {
        final parser = ArgParser();
        cockpitAddOutputArgs(parser);
        final output = StringBuffer();

        await cockpitWriteJsonPayload(
          commandName: 'read-app',
          payload: const <String, Object?>{
            'recommendedNextStep': 'runNextCommand',
            'currentRouteName': '/inbox',
            'transportType': 'remoteHttp',
            'selectedPlane': 'flutterSemanticPlane',
            'uiSummary': <String, Object?>{
              'visibleTargetCount': 4,
              'textPreviews': <String>['Inbox', 'Settings', 'Save'],
            },
            'snapshot': <String, Object?>{
              'focus': <String, Object?>{
                'hasPrimaryFocus': true,
                'primaryFocusLabel': 'Search',
                'primaryFocusWidgetType': 'TextField',
                'isTextInputFocus': true,
              },
            },
            'artifactDownloads': <Object?>[],
          },
          argResults: parser.parse(const <String>[]),
          stdoutSink: output,
        );

        final text = output.toString();
        expect(text, contains('cockpit.v=1'));
        expect(text, contains('command=read-app'));
        expect(text, contains('status=ok'));
        expect(text, contains('next=runNextCommand'));
        expect(text, contains('route=/inbox'));
        expect(text, contains('text=Inbox | Settings | Save'));
        expect(text, contains('focus=Search'));
        expect(text, contains('textInputFocus=true'));
        expect(() => jsonDecode(text), throwsA(isA<FormatException>()));
      },
    );

    test('can write compact JSON to stdout for jq pipelines', () async {
      final parser = ArgParser();
      cockpitAddOutputArgs(parser);
      final output = StringBuffer();

      await cockpitWriteJsonPayload(
        commandName: 'read-app',
        payload: const <String, Object?>{'currentRouteName': '/inbox'},
        argResults: parser.parse(const <String>['--stdout-format', 'json']),
        stdoutSink: output,
      );

      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(decoded['currentRouteName'], '/inbox');
      expect(output.toString(), isNot(contains('\n  "')));
    });

    test('renders top-level action failures as failed with issues', () async {
      final parser = ArgParser();
      cockpitAddOutputArgs(parser);
      final output = StringBuffer();

      await cockpitWriteJsonPayload(
        commandName: 'run-system-action',
        payload: const <String, Object?>{
          'success': false,
          'recommendedNextStep': 'inspectShellFailure',
          'platform': 'android',
          'action': 'tap',
          'errorCode': 'systemActionProcessFailed',
          'errorMessage': 'Unable to start process',
        },
        argResults: parser.parse(const <String>[]),
        stdoutSink: output,
      );

      final text = output.toString();
      expect(text, contains('status=failed'));
      expect(text, contains('next=inspectShellFailure'));
      expect(text, contains('platform=android'));
      expect(text, contains('action=tap'));
      expect(text, contains('errorCode=systemActionProcessFailed'));
      expect(text, contains('errorMessage=Unable to start process'));
    });

    test(
      'renders system action command arrays in the results section',
      () async {
        final parser = ArgParser();
        cockpitAddOutputArgs(parser);
        final output = StringBuffer();

        await cockpitWriteJsonPayload(
          commandName: 'run-system-action',
          payload: const <String, Object?>{
            'success': true,
            'recommendedNextStep': 'readPostActionState',
            'platform': 'android',
            'action': 'tap',
            'command': <String>[
              'adb',
              '-s',
              'emulator-5554',
              'shell',
              'input',
              'tap',
              '42',
              '88',
            ],
            'exitCode': 0,
          },
          argResults: parser.parse(const <String>[]),
          stdoutSink: output,
        );

        final text = output.toString();
        expect(text, contains('results'));
        expect(
          text,
          contains(
            'command=[adb | -s | emulator-5554 | shell | input | tap | 42 | 88]',
          ),
        );
        expect(text, contains('exitCode=0'));
      },
    );

    test(
      'renders system evidence source paths and recording results by default',
      () async {
        final parser = ArgParser();
        cockpitAddOutputArgs(parser);
        final output = StringBuffer();

        await cockpitWriteJsonPayload(
          commandName: 'run-system-action',
          payload: const <String, Object?>{
            'success': true,
            'recommendedNextStep': 'readPostActionState',
            'platform': 'android',
            'action': 'stopRecording',
            'sourceFilePath': '/tmp/system-flow.mp4',
            'recordingResult': <String, Object?>{
              'state': 'completed',
              'recordingKind': 'nativeScreen',
              'sourceFilePath': '/tmp/system-flow.mp4',
            },
          },
          argResults: parser.parse(const <String>[]),
          stdoutSink: output,
        );

        final text = output.toString();
        expect(text, contains('sourceFilePath=/tmp/system-flow.mp4'));
        expect(text, contains('recordingResult='));
        expect(text, contains('state=completed'));
        expect(text, contains('recordingKind=nativeScreen'));
      },
    );

    test('renders capability matrices as readable full rows', () async {
      final parser = ArgParser();
      cockpitAddOutputArgs(parser);
      final output = StringBuffer();

      await cockpitWriteJsonPayload(
        commandName: 'read-system-capabilities',
        payload: const <String, Object?>{
          'platform': 'macos',
          'adapter': 'macos.accessibility+screencapture',
          'preferredPlane': 'flutterSemanticPlane',
          'availableActions': <String>['tap'],
          'blockedActions': <String>['readUiTree'],
          'capabilities': <Object?>[
            <String, Object?>{
              'action': 'tap',
              'availability': 'available',
              'plane': 'deviceSystemPlane',
              'strategy': 'Accessibility API + CGEvent',
              'requires': <String>['Accessibility permission'],
              'parameters': <Object?>[
                <String, Object?>{
                  'name': 'x',
                  'required': true,
                  'valueType': 'integer',
                },
                <String, Object?>{
                  'name': 'y',
                  'required': true,
                  'valueType': 'integer',
                },
                <String, Object?>{
                  'name': 'wifiBars',
                  'valueType': 'integer',
                  'minimum': 0,
                  'maximum': 3,
                },
              ],
            },
            <String, Object?>{
              'action': 'readUiTree',
              'availability': 'blocked',
              'plane': 'nativeUiPlane',
              'strategy': 'accessibility-tree-dumper',
              'requires': <String>['Accessibility tree dump helper'],
            },
          ],
        },
        argResults: parser.parse(const <String>[]),
        stdoutSink: output,
      );

      final text = output.toString();
      expect(text, contains('\ncapabilities\n'));
      expect(text, contains('[0] action=tap availability=available'));
      expect(
        text,
        contains(
          'parameters=[x*:integer | y*:integer | wifiBars:integer[0..3]]',
        ),
      );
      expect(text, contains('[1] action=readUiTree availability=blocked'));
      expect(text, isNot(contains('\ndata\n  capabilities=')));
      expect(text, isNot(contains('\ndata\n  adapter=')));
    });

    test(
      'defaults stdout to output file paths when files are requested',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_cli_output_paths',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final aiFile = File('${tempDir.path}/result.ai');
        final parser = ArgParser();
        cockpitAddOutputArgs(parser);
        final output = StringBuffer();

        await cockpitWriteJsonPayload(
          commandName: 'run-command',
          payload: const <String, Object?>{
            'command': <String, Object?>{
              'commandId': 'tap-save',
              'commandType': 'tap',
              'success': true,
            },
          },
          argResults: parser.parse(<String>['--output', aiFile.path]),
          stdoutSink: output,
        );

        expect(output.toString().trim(), 'output=${aiFile.path}');
        expect(await aiFile.readAsString(), contains('command=run-command'));
      },
    );

    test('can write pretty JSON files with output-format json', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_cli_output_json',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final jsonFile = File('${tempDir.path}/result.json');
      final parser = ArgParser();
      cockpitAddOutputArgs(parser);
      final output = StringBuffer();

      await cockpitWriteJsonPayload(
        commandName: 'run-command',
        payload: const <String, Object?>{
          'command': <String, Object?>{
            'commandId': 'tap-save',
            'commandType': 'tap',
            'success': true,
          },
        },
        argResults: parser.parse(<String>[
          '--output',
          jsonFile.path,
          '--output-format',
          'json',
        ]),
        stdoutSink: output,
      );

      expect(output.toString().trim(), 'output=${jsonFile.path}');
      expect(await jsonFile.readAsString(), contains('\n  "command"'));
      expect(
        (jsonDecode(await jsonFile.readAsString()) as Map<String, Object?>)
            .containsKey('command'),
        isTrue,
      );
    });
  });
}
