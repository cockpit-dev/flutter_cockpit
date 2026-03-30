import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_cockpit/src/executor/in_app/cockpit_semantic_command_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes semantic-family commands to the configured handlers', () async {
    final handled = <CockpitCommandType>[];
    final executor = CockpitSemanticCommandExecutor(
      tap: _handlerFor(handled),
      longPress: _handlerFor(handled),
      doubleTap: _handlerFor(handled),
      showOnScreen: _handlerFor(handled),
      increase: _handlerFor(handled),
      decrease: _handlerFor(handled),
      dismiss: _handlerFor(handled),
    );

    await executor.execute(
      CockpitCommand(
          commandId: 'cmd-show', commandType: CockpitCommandType.showOnScreen),
      Stopwatch()..start(),
    );

    expect(handled, <CockpitCommandType>[CockpitCommandType.showOnScreen]);
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
