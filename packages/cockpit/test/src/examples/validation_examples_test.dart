import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/application/cockpit_validate_task_service.dart';
import 'package:cockpit/src/cli/cockpit_control_script.dart';
import 'package:cockpit/src/runner/cockpit_workflow_step.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final repoRoot = _findRepoRoot();
  final validationDir = Directory(
    p.join(repoRoot.path, 'examples', 'cockpit_demo', 'cockpit', 'validation'),
  );

  test('workflow YAML examples decode through the production parser', () {
    final files = <String>[
      'rapid-smoke.workflow.yaml',
      'commands-only.workflow.yaml',
      'adaptive-flow.workflow.yaml',
      'comprehensive.workflow.yaml',
      'recorded-acceptance.workflow.yaml',
    ];

    for (final name in files) {
      final script = cockpitControlScriptFromText(
        File(p.join(validationDir.path, name)).readAsStringSync(),
      );

      expect(script.schemaVersion, 1, reason: name);
      expect(script.platform, 'macos', reason: name);
      expect(script.effectiveWorkflowSteps, isNotEmpty, reason: name);
      expect(
        script.effectiveWorkflowSteps.any(_containsScreenshot),
        isTrue,
        reason: name,
      );
    }
  });

  test('commands-only example uses the top-level commands shorthand', () {
    final source = File(
      p.join(validationDir.path, 'commands-only.workflow.yaml'),
    ).readAsStringSync();
    final decoded = _decodeYamlMap(source);
    _expectKnownWorkflowKeys(decoded);
    final script = cockpitControlScriptFromText(source);

    expect(script.commands, hasLength(2));
    expect(script.workflowSteps, isEmpty);
    expect(script.effectiveWorkflowSteps, hasLength(2));
    expect(script.effectiveWorkflowSteps.any(_containsScreenshot), isTrue);
  });

  test('rapid smoke example is deterministic with or without demo data', () {
    final script = cockpitControlScriptFromText(
      File(
        p.join(validationDir.path, 'rapid-smoke.workflow.yaml'),
      ).readAsStringSync(),
    );
    final assertedTexts = _allSteps(script.effectiveWorkflowSteps)
        .whereType<CockpitCommandWorkflowStep>()
        .where(
          (step) => step.command.commandType == CockpitCommandType.assertText,
        )
        .map((step) => step.command.parameters['text'])
        .whereType<String>()
        .toList();

    expect(assertedTexts, contains('Inbox'));
    expect(assertedTexts, contains('New task'));
    expect(assertedTexts, isNot(contains('Search title or notes')));
    expect(assertedTexts, isNot(contains('Fresh canvas')));
    expect(assertedTexts, isNot(contains('Create task')));
    expect(assertedTexts, isNot(contains('No tasks yet')));
    expect(assertedTexts, isNot(contains('Queue brief:')));
  });

  test('validation workflow reads the actual run-script bundle directory', () {
    final workflow = File(
      p.join(repoRoot.path, '.github', 'workflows', 'validation-examples.yml'),
    ).readAsStringSync();

    expect(workflow, contains('RUN_SCRIPT_BUNDLE_DIR='));
    expect(
      workflow,
      isNot(
        contains(
          'read-task-bundle-summary \\\n            --bundle-dir "\$BUNDLE_DIR"',
        ),
      ),
    );
  });

  test(
    'validation examples run the reusable smoke workflow on every platform',
    () {
      final workflow = File(
        p.join(
          repoRoot.path,
          '.github',
          'workflows',
          'validation-examples.yml',
        ),
      ).readAsStringSync();
      final decoded = _decodeYamlMap(workflow);
      final jobs = decoded['jobs']! as Map<String, Object?>;
      final validationJob = jobs['validation-example'] as Map<String, Object?>?;

      expect(validationJob, isNotNull);
      final strategy = validationJob!['strategy']! as Map<String, Object?>;
      final matrix = strategy['matrix']! as Map<String, Object?>;
      final include = matrix['include']! as List<Object?>;
      final platforms = include
          .cast<Map<String, Object?>>()
          .map((entry) => entry['platform'])
          .toSet();

      expect(
        platforms,
        equals(<String>{'android', 'ios', 'macos', 'linux', 'windows', 'web'}),
      );
      expect(workflow, contains('export VALIDATION_PLATFORM='));
      expect(
        workflow,
        contains('assert data["manifest"]["platform"] == platform'),
      );
    },
  );

  test('validation examples document all supported platform invocations', () {
    final readme = File(
      p.join(validationDir.path, 'README.md'),
    ).readAsStringSync();

    expect(readme, contains('Supported overrides'));
    expect(readme, contains('android'));
    expect(readme, contains('ios'));
    expect(readme, contains('macos'));
    expect(readme, contains('linux'));
    expect(readme, contains('windows'));
    expect(readme, contains('web'));
    expect(readme, contains('run-script --platform'));
    expect(readme, contains('same YAML'));
  });

  test('Android validation example script is POSIX sh compatible', () {
    final workflow = File(
      p.join(repoRoot.path, '.github', 'workflows', 'validation-examples.yml'),
    ).readAsStringSync();
    final step = _workflowStep(
      workflow,
      'Run rapid validation workflow example (Android)',
    );
    final withBlock = step['with']! as Map<String, Object?>;
    final script = withBlock['script']! as String;
    final driver = File(
      p.join(
        repoRoot.path,
        '.github',
        'scripts',
        'run-validation-example-android.sh',
      ),
    );

    expect(script, isNot(contains('bash -lc')));
    expect(script, isNot(contains('pipefail')));
    expect(
      script.trim(),
      r'bash "$GITHUB_WORKSPACE/.github/scripts/run-validation-example-android.sh"',
    );
    expect(driver.existsSync(), isTrue);

    final driverSource = driver.readAsStringSync();
    expect(
      driverSource,
      contains(r'cd "$GITHUB_WORKSPACE/examples/cockpit_demo/cockpit"'),
    );
    expect(driverSource, contains('dart run cockpit launch-app'));
    expect(driverSource, contains('dart run cockpit run-script'));
    expect(driverSource, contains(r'> "$LOG_PATH" 2>&1'));
    expect(driverSource, contains(r'cat "$LOG_PATH"'));
  });

  test(
    'Linux and web validation examples keep launch and script in one Xvfb session',
    () {
      final workflow = File(
        p.join(
          repoRoot.path,
          '.github',
          'workflows',
          'validation-examples.yml',
        ),
      ).readAsStringSync();
      final step = _workflowStep(
        workflow,
        'Run rapid validation workflow example',
      );
      final env = step['env']! as Map<String, Object?>;
      final script = step['run']! as String;

      expect(env, contains('VALIDATION_DRIVER'));
      expect(script, contains(r'xvfb-run -a "$VALIDATION_DRIVER"'));
      expect(script, isNot(contains('RUNNER_PREFIX=(xvfb-run -a)')));
    },
  );

  test('validation example installs Linux plugin build dependencies', () {
    final workflow = File(
      p.join(repoRoot.path, '.github', 'workflows', 'validation-examples.yml'),
    ).readAsStringSync();
    final linuxInstall = RegExp(
      r'linux\)([\s\S]*?)flutter config --enable-linux-desktop',
    ).firstMatch(workflow)!.group(1)!;

    expect(linuxInstall, contains('libgtk-3-dev'));
    expect(linuxInstall, contains('clang'));
    expect(linuxInstall, contains('cmake'));
    expect(linuxInstall, contains('ninja-build'));
    expect(linuxInstall, contains('pkg-config'));
    expect(linuxInstall, contains('xvfb'));
    expect(linuxInstall, contains('x11-utils'));
    expect(linuxInstall, contains('libgstreamer1.0-dev'));
    expect(linuxInstall, contains('libgstreamer-plugins-base1.0-dev'));
    expect(linuxInstall, contains('gstreamer1.0-libav'));
    expect(workflow, contains('--no-install-recommends'));
  });

  test(
    'platform capability workflow avoids installing recommended apt payloads',
    () {
      final workflow = File(
        p.join(
          repoRoot.path,
          '.github',
          'workflows',
          'platform-capabilities.yml',
        ),
      ).readAsStringSync();

      expect(workflow, contains('DEBIAN_FRONTEND: noninteractive'));
      expect(
        workflow,
        contains('sudo apt-get install -y --no-install-recommends'),
      );
      expect(workflow, isNot(contains('sudo apt-get install -y ffmpeg x11')));
    },
  );

  test('example workflow gives Linux desktop dependencies enough time', () {
    final workflow = File(
      p.join(repoRoot.path, '.github', 'workflows', 'example-e2e.yml'),
    ).readAsStringSync();

    expect(workflow, contains('DEBIAN_FRONTEND: noninteractive'));
    expect(
      workflow,
      contains('sudo apt-get install -y --no-install-recommends'),
    );
    expect(workflow, contains('timeout-minutes: 25'));
  });

  test('adaptive example exercises branch and loop workflow nodes', () {
    final script = cockpitControlScriptFromText(
      File(
        p.join(validationDir.path, 'adaptive-flow.workflow.yaml'),
      ).readAsStringSync(),
    );

    expect(
      script.effectiveWorkflowSteps.whereType<CockpitIfWorkflowStep>(),
      isNotEmpty,
    );
    expect(
      script.effectiveWorkflowSteps.whereType<CockpitLoopWorkflowStep>(),
      isNotEmpty,
    );
  });

  test(
    'adaptive example optional dialog probe does not match launcher button',
    () {
      final script = cockpitControlScriptFromText(
        File(
          p.join(validationDir.path, 'adaptive-flow.workflow.yaml'),
        ).readAsStringSync(),
      );
      final optionalDialogStep = script.effectiveWorkflowSteps
          .whereType<CockpitIfWorkflowStep>()
          .singleWhere((step) => step.stepId == 'close-settings-if-open');

      expect(
        optionalDialogStep.condition.commandType,
        CockpitCommandType.assertVisible,
      );
      expect(optionalDialogStep.condition.locator?.tooltip, 'Close');
      expect(
        optionalDialogStep.condition.parameters.values,
        isNot(contains('Settings')),
      );
    },
  );

  test('recorded acceptance example exercises step-scoped recording', () {
    final script = cockpitControlScriptFromText(
      File(
        p.join(validationDir.path, 'recorded-acceptance.workflow.yaml'),
      ).readAsStringSync(),
    );

    expect(script.requestsRecording, isTrue);
    expect(
      script.effectiveWorkflowSteps
          .whereType<CockpitStartRecordingWorkflowStep>(),
      hasLength(1),
    );
    expect(
      script.effectiveWorkflowSteps
          .whereType<CockpitStopRecordingWorkflowStep>(),
      hasLength(1),
    );
  });

  test('comprehensive example covers its declared workflow surface', () {
    final source = File(
      p.join(validationDir.path, 'comprehensive.workflow.yaml'),
    ).readAsStringSync();
    final decoded = _decodeYamlMap(source);
    _expectKnownWorkflowKeys(decoded);
    final script = cockpitControlScriptFromText(source);

    expect(script.recording, isNull);
    expect(script.requestsRecording, isTrue);
    expect(_allSteps(script.effectiveWorkflowSteps), isNotEmpty);
    final commandTypes = _allSteps(script.effectiveWorkflowSteps)
        .whereType<CockpitCommandWorkflowStep>()
        .map((step) => step.command.commandType)
        .toSet();
    expect(
      commandTypes,
      containsAll(<CockpitCommandType>[
        CockpitCommandType.tap,
        CockpitCommandType.enterText,
        CockpitCommandType.captureScreenshot,
        CockpitCommandType.collectSnapshot,
      ]),
    );
    expect(
      _allSteps(
        script.effectiveWorkflowSteps,
      ).map((step) => step.stepType).toSet(),
      containsAll(<String>[
        'command',
        'if',
        'loop',
        'retry',
        'startRecording',
        'stopRecording',
      ]),
    );
  });

  test(
    'workflow contract schema matches the command surface used by examples',
    () {
      final schemaFile = File(
        p.join(
          repoRoot.path,
          'docs',
          'contracts',
          'control-workflow.schema.json',
        ),
      );
      final packageSchemaFile = File(
        p.join(
          repoRoot.path,
          'packages',
          'cockpit',
          'doc',
          'contracts',
          'control-workflow.schema.json',
        ),
      );
      final schemaSource = schemaFile.readAsStringSync();
      expect(packageSchemaFile.readAsStringSync(), schemaSource);

      final schema = jsonDecode(schemaSource) as Map<String, Object?>;
      final defs = schema[r'$defs']! as Map<String, Object?>;
      final commandType = defs['commandType']! as Map<String, Object?>;
      expect(
        commandType['enum'],
        CockpitCommandType.values.map((type) => type.name).toList(),
      );

      final command = defs['command']! as Map<String, Object?>;
      final commandProperties = command['properties']! as Map<String, Object?>;
      expect(
        commandProperties.keys,
        containsAll(<String>[
          'capturePolicy',
          'captureFailurePolicy',
          'timeoutMs',
          'snapshotOptions',
          'screenshotRequest',
        ]),
      );

      final snapshotOptions = defs['snapshotOptions']! as Map<String, Object?>;
      final snapshotProperties =
          snapshotOptions['properties']! as Map<String, Object?>;
      expect(
        snapshotProperties.keys,
        containsAll(<String>[
          'profile',
          'maxTargets',
          'includeNetworkActivity',
          'networkQuery',
          'includeRuntimeActivity',
          'runtimeQuery',
          'includeAccessibilitySummary',
        ]),
      );
    },
  );

  test(
    'workflow protocol document is synced into the published package copy',
    () {
      final workspaceProtocol = File(
        p.join(
          repoRoot.path,
          'docs',
          'contracts',
          'control-workflow-protocol.md',
        ),
      ).readAsStringSync();
      final packageProtocol = File(
        p.join(
          repoRoot.path,
          'packages',
          'cockpit',
          'doc',
          'contracts',
          'control-workflow-protocol.md',
        ),
      ).readAsStringSync();

      expect(packageProtocol, workspaceProtocol);
      expect(workspaceProtocol, contains('Top-level `commands`'));
      expect(workspaceProtocol, contains('Screenshot request fields'));
    },
  );

  test(
    'validate-task YAML example decodes through production config model',
    () {
      final source = File(
        p.join(validationDir.path, 'validate-task.macos.yaml'),
      ).readAsStringSync();
      final config = _decodeYamlMap(source);
      final request = CockpitValidateTaskRequest.fromJson(config);

      expect(request.runTask.launch?.platform, 'macos');
      expect(request.runTask.launch?.target, 'main.dart');
      expect(request.runTask.script.requestsRecording, isTrue);
      expect(request.runTask.requirements.requireScreenshotEvidence, isTrue);
      expect(request.runTask.requirements.requireVideoEvidence, isTrue);
      expect(request.validation.requirePrimaryScreenshot, isTrue);
      expect(request.validation.requirePrimaryRecording, isTrue);
      expect(request.validation.requireArtifactFiles, isTrue);
    },
  );
}

bool _containsScreenshot(CockpitWorkflowStep step) {
  return switch (step) {
    CockpitCommandWorkflowStep() =>
      step.command.commandType.name == 'captureScreenshot',
    CockpitIfWorkflowStep() =>
      step.thenSteps.any(_containsScreenshot) ||
          step.elseSteps.any(_containsScreenshot),
    CockpitLoopWorkflowStep() => step.steps.any(_containsScreenshot),
    CockpitRetryWorkflowStep() => _containsScreenshot(step.step),
    CockpitStartRecordingWorkflowStep() => false,
    CockpitStopRecordingWorkflowStep() => false,
  };
}

List<CockpitWorkflowStep> _allSteps(List<CockpitWorkflowStep> steps) {
  return <CockpitWorkflowStep>[
    for (final step in steps) ...<CockpitWorkflowStep>[
      step,
      ...switch (step) {
        CockpitIfWorkflowStep() => <CockpitWorkflowStep>[
          ..._allSteps(step.thenSteps),
          ..._allSteps(step.elseSteps),
        ],
        CockpitLoopWorkflowStep() => _allSteps(step.steps),
        CockpitRetryWorkflowStep() => _allSteps(<CockpitWorkflowStep>[
          step.step,
        ]),
        CockpitCommandWorkflowStep() ||
        CockpitStartRecordingWorkflowStep() ||
        CockpitStopRecordingWorkflowStep() => const <CockpitWorkflowStep>[],
      },
    ],
  ];
}

Directory _findRepoRoot() {
  var current = Directory.current;
  while (true) {
    if (File(p.join(current.path, 'melos.yaml')).existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('Unable to locate repository root.');
    }
    current = parent;
  }
}

Map<String, Object?> _decodeYamlMap(String source) {
  final decoded = loadYaml(source);
  if (decoded is! Map<Object?, Object?>) {
    throw StateError('Expected YAML object.');
  }
  return _stringKeyedMap(decoded);
}

Map<String, Object?> _workflowStep(String source, String name) {
  final decoded = _decodeYamlMap(source);
  final jobs = decoded['jobs']! as Map<String, Object?>;
  final validationJob = jobs['validation-example']! as Map<String, Object?>;
  final steps = validationJob['steps']! as List<Object?>;
  return steps.cast<Map<String, Object?>>().firstWhere(
    (step) => step['name'] == name,
  );
}

Object? _normalizeYamlValue(Object? value) {
  return switch (value) {
    Map<Object?, Object?>() => _stringKeyedMap(value),
    List<Object?>() => value.map(_normalizeYamlValue).toList(growable: false),
    _ => value,
  };
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> input) {
  return input.map(
    (key, value) => MapEntry(key as String, _normalizeYamlValue(value)),
  );
}

void _expectKnownWorkflowKeys(Map<String, Object?> script) {
  _expectKeys(script, <String>{
    'schemaVersion',
    'sessionId',
    'taskId',
    'platform',
    'environment',
    'recording',
    'commands',
    'failFast',
    'steps',
  }, 'script');
  final environment = script['environment'];
  if (environment != null) {
    _expectKeys(environment as Map<String, Object?>, <String>{
      'platform',
      'flutterVersion',
      'dartVersion',
    }, 'script.environment');
  }
  final recording = script['recording'];
  if (recording != null) {
    _expectRecordingKeys(recording as Map<String, Object?>);
  }
  final commands = script['commands'];
  if (commands != null) {
    for (final (index, command) in (commands as List<Object?>).indexed) {
      _expectCommandKeys(command as Map<String, Object?>);
      expect(command['commandId'], isNotEmpty, reason: 'commands[$index]');
    }
  }
  final steps = script['steps'];
  if (steps != null) {
    for (final (index, step) in (steps as List<Object?>).indexed) {
      _expectStepKeys(step as Map<String, Object?>, 'script.steps[$index]');
    }
  }
}

void _expectStepKeys(Map<String, Object?> step, String path) {
  _expectKeys(step, <String>{
    'stepId',
    'stepType',
    'command',
    'recording',
    'settleMs',
    'condition',
    'thenSteps',
    'elseSteps',
    'maxAttempts',
    'delayMs',
    'step',
    'maxIterations',
    'steps',
  }, path);
  switch (step['stepType']) {
    case 'command':
      _expectCommandKeys(step['command']! as Map<String, Object?>);
    case 'startRecording':
      _expectRecordingKeys(step['recording']! as Map<String, Object?>);
    case 'stopRecording':
      break;
    case 'if':
      _expectCommandKeys(step['condition']! as Map<String, Object?>);
      for (final (index, child)
          in (step['thenSteps']! as List<Object?>).indexed) {
        _expectStepKeys(
          child as Map<String, Object?>,
          '$path.thenSteps[$index]',
        );
      }
      for (final (index, child)
          in ((step['elseSteps'] as List<Object?>?) ?? const <Object?>[])
              .indexed) {
        _expectStepKeys(
          child as Map<String, Object?>,
          '$path.elseSteps[$index]',
        );
      }
    case 'loop':
      _expectCommandKeys(step['condition']! as Map<String, Object?>);
      for (final (index, child) in (step['steps']! as List<Object?>).indexed) {
        _expectStepKeys(child as Map<String, Object?>, '$path.steps[$index]');
      }
    case 'retry':
      _expectStepKeys(step['step']! as Map<String, Object?>, '$path.step');
  }
}

void _expectCommandKeys(Map<String, Object?> command) {
  _expectKeys(command, <String>{
    'commandId',
    'commandType',
    'locator',
    'parameters',
    'capturePolicy',
    'captureFailurePolicy',
    'timeoutMs',
    'snapshotOptions',
    'screenshotRequest',
  }, '${command['commandId'] ?? 'command'}');
  final locator = command['locator'];
  if (locator != null) {
    _expectLocatorKeys(
      locator as Map<String, Object?>,
      '${command['commandId']}.locator',
    );
  }
  final snapshotOptions = command['snapshotOptions'];
  if (snapshotOptions != null) {
    _expectSnapshotOptionsKeys(
      snapshotOptions as Map<String, Object?>,
      '${command['commandId']}.snapshotOptions',
    );
  }
  final screenshotRequest = command['screenshotRequest'];
  if (screenshotRequest != null) {
    final request = screenshotRequest as Map<String, Object?>;
    _expectKeys(request, <String>{
      'reason',
      'name',
      'includeSnapshot',
      'attachToStep',
      'snapshotOptions',
    }, '${command['commandId']}.screenshotRequest');
    final requestSnapshotOptions = request['snapshotOptions'];
    if (requestSnapshotOptions != null) {
      _expectSnapshotOptionsKeys(
        requestSnapshotOptions as Map<String, Object?>,
        '${command['commandId']}.screenshotRequest.snapshotOptions',
      );
    }
  }
}

void _expectLocatorKeys(Map<String, Object?> locator, String path) {
  _expectKeys(locator, <String>{
    'cockpitId',
    'semanticId',
    'key',
    'text',
    'tooltip',
    'type',
    'route',
    'registrationId',
    'path',
    'index',
    'ancestor',
    'fallbacks',
  }, path);
  final ancestor = locator['ancestor'];
  if (ancestor != null) {
    _expectLocatorKeys(ancestor as Map<String, Object?>, '$path.ancestor');
  }
  final fallbacks = locator['fallbacks'];
  if (fallbacks != null) {
    for (final (index, fallback) in (fallbacks as List<Object?>).indexed) {
      _expectLocatorKeys(
        fallback as Map<String, Object?>,
        '$path.fallbacks[$index]',
      );
    }
  }
}

void _expectSnapshotOptionsKeys(Map<String, Object?> options, String path) {
  _expectKeys(options, <String>{
    'profile',
    'maxTargets',
    'maxAncestorsPerTarget',
    'maxPropertiesPerTarget',
    'includeStyleDetails',
    'includeDiagnosticProperties',
    'emitArtifactWhenLarge',
    'includeRebuildActivity',
    'maxRebuildEntries',
    'includeNetworkActivity',
    'maxNetworkEntries',
    'networkQuery',
    'includeRuntimeActivity',
    'maxRuntimeEntries',
    'runtimeQuery',
    'includeAccessibilitySummary',
    'maxAccessibilityEntries',
  }, path);
  final networkQuery = options['networkQuery'];
  if (networkQuery != null) {
    _expectKeys(networkQuery as Map<String, Object?>, <String>{
      'method',
      'uriContains',
      'onlyFailures',
      'statusCodeAtLeast',
    }, '$path.networkQuery');
  }
  final runtimeQuery = options['runtimeQuery'];
  if (runtimeQuery != null) {
    _expectKeys(runtimeQuery as Map<String, Object?>, <String>{
      'onlyErrors',
      'messageContains',
    }, '$path.runtimeQuery');
  }
}

void _expectRecordingKeys(Map<String, Object?> recording) {
  _expectKeys(recording, <String>{
    'purpose',
    'name',
    'mode',
    'layer',
    'allowFallback',
    'attachToStep',
    'tailStabilizationMs',
  }, '${recording['name'] ?? 'recording'}');
}

void _expectKeys(Map<String, Object?> value, Set<String> allowed, String path) {
  final unknown = value.keys.where((key) => !allowed.contains(key)).toList();
  expect(unknown, isEmpty, reason: '$path has unsupported keys');
}
