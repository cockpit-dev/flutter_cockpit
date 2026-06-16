import 'dart:io';

abstract interface class CockpitShellDriver {
  Future<ProcessResult> runShell(List<String> command);
}
