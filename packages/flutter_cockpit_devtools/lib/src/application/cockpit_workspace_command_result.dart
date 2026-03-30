final class CockpitWorkspaceCommand {
  const CockpitWorkspaceCommand({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;

  Map<String, Object?> toJson() => <String, Object?>{
        'executable': executable,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
      };
}

final class CockpitWorkspaceCommandResult {
  const CockpitWorkspaceCommandResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final CockpitWorkspaceCommand command;
  final int exitCode;
  final String stdout;
  final String stderr;

  bool get success => exitCode == 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'command': command.toJson(),
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'success': success,
      };
}
