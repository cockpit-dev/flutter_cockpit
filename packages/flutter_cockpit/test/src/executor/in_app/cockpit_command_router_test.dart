import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_cockpit/src/executor/in_app/cockpit_command_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes a command to its registered specialist handler', () async {
    final handledTypes = <CockpitCommandType>[];
    final router = CockpitCommandRouter(
      handlers: <CockpitCommandType, CockpitInAppCommandHandler>{
        CockpitCommandType.tap: (command, stopwatch) async {
          handledTypes.add(command.commandType);
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: stopwatch.elapsedMilliseconds,
            ),
          );
        },
      },
    );

    final stopwatch = Stopwatch()..start();
    final execution = await router.execute(
      CockpitCommand(commandId: 'cmd-tap', commandType: CockpitCommandType.tap),
      stopwatch,
    );

    expect(handledTypes, <CockpitCommandType>[CockpitCommandType.tap]);
    expect(execution.result.success, isTrue);
    expect(execution.result.commandType, CockpitCommandType.tap);
  });

  test('fails fast when no handler is registered for a command type', () async {
    final router = CockpitCommandRouter(handlers: const {});

    expect(
      () => router.execute(
        CockpitCommand(
          commandId: 'cmd-wait',
          commandType: CockpitCommandType.waitFor,
        ),
        Stopwatch()..start(),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
