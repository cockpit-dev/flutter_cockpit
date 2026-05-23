import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_cockpit/src/executor/in_app/cockpit_wait_and_assert_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes wait/assert commands to the configured handlers', () async {
    final handled = <CockpitCommandType>[];
    final executor = CockpitWaitAndAssertExecutor(
      scrollUntilVisible: _handlerFor(handled),
      waitForNetworkIdle: _handlerFor(handled),
      waitForUiIdle: _handlerFor(handled),
      assertVisible: _handlerFor(handled),
      assertText: _handlerFor(handled),
      waitFor: _handlerFor(handled),
    );

    await executor.execute(
      CockpitCommand(
        commandId: 'cmd-assert-text',
        commandType: CockpitCommandType.assertText,
      ),
      Stopwatch()..start(),
    );

    expect(handled, <CockpitCommandType>[CockpitCommandType.assertText]);
  });
}

Future<CockpitCommandExecution> Function(CockpitCommand, Stopwatch) _handlerFor(
  List<CockpitCommandType> handled,
) {
  return (command, stopwatch) async {
    handled.add(command.commandType);
    return CockpitCommandExecution(
      result: CockpitCommandResult(
        success: true,
        commandId: command.commandId,
        commandType: command.commandType,
        durationMs: stopwatch.elapsedMilliseconds,
      ),
    );
  };
}
