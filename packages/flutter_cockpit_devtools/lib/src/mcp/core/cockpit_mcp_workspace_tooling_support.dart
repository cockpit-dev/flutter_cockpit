import 'package:dart_mcp/server.dart';

import '../../application/cockpit_workspace_tooling_support.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import 'cockpit_mcp_roots_tracker.dart';

List<String> cockpitAllowedWorkspaceRootPaths(
  CockpitMcpRootsTracker rootsTracker,
) {
  return cockpitPathsFromRootUris(
    rootsTracker.effectiveRoots.map((root) => root.uri),
  );
}

String cockpitResolveWorkspaceRootFromArguments(
  Map<String, Object?> arguments,
  CockpitMcpRootsTracker rootsTracker, {
  String key = 'workspace_root',
}) {
  try {
    return resolveWorkspaceRoot(
      workspaceRoot: cockpitReadOptionalString(arguments, key),
      allowedRoots: cockpitAllowedWorkspaceRootPaths(rootsTracker),
      argumentName: key,
    );
  } on Object catch (error) {
    cockpitRethrowAsMcpError(error);
  }
}

String cockpitResolveParentDirectoryFromArguments(
  Map<String, Object?> arguments,
  CockpitMcpRootsTracker rootsTracker, {
  String key = 'parent_directory',
}) {
  try {
    return resolveWorkspaceRoot(
      workspaceRoot: cockpitReadOptionalString(arguments, key),
      allowedRoots: cockpitAllowedWorkspaceRootPaths(rootsTracker),
      argumentName: key,
    );
  } on Object catch (error) {
    cockpitRethrowAsMcpError(error);
  }
}

List<String> cockpitReadOptionalStringList(
  Map<String, Object?> arguments,
  String key,
) {
  final value = arguments[key];
  if (value == null) {
    return const <String>[];
  }
  if (value is! List<Object?>) {
    throw CockpitMcpError.invalidArguments(
      'Argument must be a list of strings.',
      details: <String, Object?>{'argument': key},
    );
  }
  final strings = value.map((item) => item).toList(growable: false);
  for (final item in strings) {
    if (item is! String || item.isEmpty) {
      throw CockpitMcpError.invalidArguments(
        'Argument must be a list of non-empty strings.',
        details: <String, Object?>{'argument': key},
      );
    }
  }
  return List<String>.unmodifiable(strings.cast<String>());
}

List<Root> cockpitReadRootObjects(
  Map<String, Object?> arguments, {
  String key = 'roots',
}) {
  final value = arguments[key];
  if (value is! List<Object?> || value.isEmpty) {
    throw CockpitMcpError.invalidArguments(
      'Missing required roots argument.',
      details: <String, Object?>{'argument': key},
    );
  }
  return List<Root>.unmodifiable(
    value.map((item) {
      if (item is! Map<Object?, Object?>) {
        throw CockpitMcpError.invalidArguments(
          'Each root must be an object.',
          details: <String, Object?>{'argument': key},
        );
      }
      final json = Map<String, Object?>.from(item);
      final uri = cockpitReadRequiredString(json, 'uri');
      final name = cockpitReadOptionalString(json, 'name');
      return Root(uri: uri, name: name);
    }),
  );
}
