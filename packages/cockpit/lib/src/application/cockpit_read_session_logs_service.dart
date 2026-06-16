import '../infrastructure/cockpit_file_system.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_session_registry.dart';

final class CockpitReadSessionLogsRequest {
  const CockpitReadSessionLogsRequest({
    required this.developmentSessionId,
    this.maxLines = 200,
  });

  final String developmentSessionId;
  final int maxLines;
}

final class CockpitReadSessionLogsResult {
  const CockpitReadSessionLogsResult({
    required this.developmentSessionId,
    required this.logPath,
    required this.lines,
    required this.truncated,
  });

  final String developmentSessionId;
  final String logPath;
  final List<String> lines;
  final bool truncated;

  Map<String, Object?> toJson() => <String, Object?>{
    'developmentSessionId': developmentSessionId,
    'logPath': logPath,
    'lines': lines,
    'truncated': truncated,
  };
}

final class CockpitReadSessionLogsService {
  CockpitReadSessionLogsService({
    required CockpitSessionRegistry registry,
    CockpitFileSystem? fileSystem,
  }) : _registry = registry,
       _fileSystem = fileSystem ?? const LocalCockpitFileSystem();

  final CockpitSessionRegistry _registry;
  final CockpitFileSystem _fileSystem;

  Future<CockpitReadSessionLogsResult> read(
    CockpitReadSessionLogsRequest request,
  ) async {
    final record = _registry.developmentSession(request.developmentSessionId);
    if (record == null) {
      throw CockpitApplicationServiceException(
        code: 'unknownDevelopmentSession',
        message: 'Unknown development session.',
        details: <String, Object?>{
          'developmentSessionId': request.developmentSessionId,
        },
      );
    }
    final logPath = record.supervisorLogPath;
    if (logPath == null || logPath.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'sessionLogsUnavailable',
        message: 'No supervisor log file is registered for this session.',
        details: <String, Object?>{
          'developmentSessionId': request.developmentSessionId,
        },
      );
    }
    final file = _fileSystem.file(logPath);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'sessionLogMissing',
        message: 'The registered session log file does not exist.',
        details: <String, Object?>{
          'developmentSessionId': request.developmentSessionId,
          'logPath': logPath,
        },
      );
    }
    final lines = await file.readAsLines();
    final safeMaxLines = request.maxLines <= 0 ? 200 : request.maxLines;
    final truncated = lines.length > safeMaxLines;
    final visibleLines = truncated
        ? lines.sublist(lines.length - safeMaxLines)
        : lines;
    return CockpitReadSessionLogsResult(
      developmentSessionId: request.developmentSessionId,
      logPath: logPath,
      lines: List<String>.unmodifiable(visibleLines),
      truncated: truncated,
    );
  }
}
