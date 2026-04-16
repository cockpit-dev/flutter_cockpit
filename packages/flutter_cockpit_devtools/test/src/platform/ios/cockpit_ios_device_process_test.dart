import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/platform/ios/cockpit_ios_device_process.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('finds and terminates physical iOS app processes by bundle id',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_ios_device_process_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final invocations = <String>[];
    final terminator = CockpitIosDeviceProcessTerminator(
      tempDirectoryPathProvider: () => tempDir.path,
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        invocations.add('$executable ${arguments.join(' ')}');
        if (arguments.length >= 4 &&
            arguments[0] == 'devicectl' &&
            arguments[1] == 'device' &&
            arguments[2] == 'info' &&
            arguments[3] == 'processes') {
          final outputPath = arguments[arguments.indexOf('--json-output') + 1];
          final outputFile = File(outputPath);
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsString(
            jsonEncode(<String, Object?>{
              'result': <String, Object?>{
                'processes': <Map<String, Object?>>[
                  <String, Object?>{
                    'processIdentifier': 404,
                    'application': <String, Object?>{
                      'bundleIdentifier': 'dev.example.other',
                    },
                  },
                  <String, Object?>{
                    'processIdentifier': 1201,
                    'application': <String, Object?>{
                      'bundleIdentifier': 'dev.example.target',
                    },
                  },
                ],
              },
            }),
          );
          return ProcessResult(0, 0, '', '');
        }
        return ProcessResult(0, 0, '', '');
      },
    );

    final pids = await terminator.findPids(
      deviceId: '00008110-0009341C2EF3801E',
      bundleId: 'dev.example.target',
    );
    final terminated = await terminator.terminateApp(
      deviceId: '00008110-0009341C2EF3801E',
      bundleId: 'dev.example.target',
    );

    expect(pids, <int>[1201]);
    expect(terminated, isTrue);
    expect(
      invocations,
      contains(
        'xcrun devicectl device process terminate --device 00008110-0009341C2EF3801E --pid 1201 --kill',
      ),
    );
    expect(
      File(
        p.join(
          tempDir.path,
          'flutter_cockpit_ios_processes_00008110-0009341C2EF3801E.json',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('findPids uses a unique temp file per invocation and cleans it up',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_ios_device_process_concurrency_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final outputPaths = <String>[];
    final terminator = CockpitIosDeviceProcessTerminator(
      tempDirectoryPathProvider: () => tempDir.path,
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        final outputPath = arguments[arguments.indexOf('--json-output') + 1];
        outputPaths.add(outputPath);
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsString(
          jsonEncode(<String, Object?>{
            'result': <String, Object?>{
              'processes': <Map<String, Object?>>[
                <String, Object?>{
                  'processIdentifier': 1201,
                  'application': <String, Object?>{
                    'bundleIdentifier': 'dev.example.target',
                  },
                },
              ],
            },
          }),
        );
        return ProcessResult(0, 0, '', '');
      },
    );

    final pids = await Future.wait(<Future<List<int>>>[
      terminator.findPids(
        deviceId: '00008110-0009341C2EF3801E',
        bundleId: 'dev.example.target',
      ),
      terminator.findPids(
        deviceId: '00008110-0009341C2EF3801E',
        bundleId: 'dev.example.target',
      ),
    ]);

    expect(pids, everyElement(<int>[1201]));
    expect(outputPaths, hasLength(2));
    expect(outputPaths[0], isNot(equals(outputPaths[1])));
    expect(tempDir.listSync(), isEmpty);
  });
}
