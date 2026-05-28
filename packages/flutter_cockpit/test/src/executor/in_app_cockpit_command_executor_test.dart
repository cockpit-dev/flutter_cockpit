import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('describeCapabilities exposes assertion and wait commands', () async {
    final registry = CockpitTargetRegistry(routeName: '/checkout');
    registry.register(
      CockpitTarget(
        registrationId: 'submit',
        cockpitId: 'submit_button',
        routeName: '/checkout',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () {},
      ),
    );

    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      captureHandler: (_) async {
        return CockpitCaptureResult(
          screenshot: CockpitCapturedScreenshot(
            artifact: const CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/capabilities.png',
            ),
            bytes: Uint8List.fromList(const <int>[137, 80, 78, 71]),
          ),
          requestedProfile: CockpitCaptureProfile.acceptance,
          resolvedCaptureKind: CockpitCaptureKind.flutterView,
        );
      },
      scrollStepHandler:
          ({
            required reverse,
            required viewportFraction,
            scrollableKey,
            targetLocator,
            scrollableLocator,
            required duration,
            required gestureProfile,
            required continuous,
            required postScrollEnsureVisible,
          }) async {
            return const CockpitScrollStepResult(didScroll: true);
          },
      gestureHandler: (_) async {},
      waitForNetworkIdleHandler:
          ({required quietWindow, required timeout}) async => true,
      backNavigationHandler: () async => true,
    );

    final capabilities = await executor.describeCapabilities();

    expect(
      capabilities.supportedCommands,
      containsAll(<CockpitCommandType>[
        CockpitCommandType.tap,
        CockpitCommandType.scrollUntilVisible,
        CockpitCommandType.waitForNetworkIdle,
        CockpitCommandType.waitForUiIdle,
        CockpitCommandType.sendKeyEvent,
        CockpitCommandType.sendKeyDownEvent,
        CockpitCommandType.sendKeyUpEvent,
        CockpitCommandType.showOnScreen,
        CockpitCommandType.increase,
        CockpitCommandType.decrease,
        CockpitCommandType.dismiss,
        CockpitCommandType.focusTextInput,
        CockpitCommandType.setTextEditingValue,
        CockpitCommandType.sendTextInputAction,
        CockpitCommandType.longPress,
        CockpitCommandType.doubleTap,
        CockpitCommandType.drag,
        CockpitCommandType.fling,
        CockpitCommandType.swipe,
        CockpitCommandType.pinchZoom,
        CockpitCommandType.rotate,
        CockpitCommandType.panZoom,
        CockpitCommandType.multiTouch,
        CockpitCommandType.back,
        CockpitCommandType.assertVisible,
        CockpitCommandType.assertText,
        CockpitCommandType.waitFor,
        CockpitCommandType.collectSnapshot,
        CockpitCommandType.captureScreenshot,
      ]),
    );
  });

  test(
    'describeCapabilities exposes clearNetworkActivity when available',
    () async {
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/checkout'),
        clearNetworkActivityHandler: () {},
        waitForNetworkIdleHandler:
            ({required quietWindow, required timeout}) async => true,
        backNavigationHandler: () async => true,
      );

      final capabilities = await executor.describeCapabilities();

      expect(
        capabilities.supportedCommands,
        containsAll(<CockpitCommandType>[
          CockpitCommandType.clearNetworkActivity,
          CockpitCommandType.waitForNetworkIdle,
          CockpitCommandType.waitForUiIdle,
        ]),
      );
    },
  );

  test(
    'describeCapabilities reports executor-level commands even without visible targets',
    () async {
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/empty'),
      );

      final capabilities = await executor.describeCapabilities();

      expect(
        capabilities.supportedCommands,
        containsAll(<CockpitCommandType>[
          CockpitCommandType.tap,
          CockpitCommandType.enterText,
          CockpitCommandType.longPress,
          CockpitCommandType.doubleTap,
          CockpitCommandType.assertVisible,
          CockpitCommandType.assertText,
          CockpitCommandType.waitFor,
          CockpitCommandType.collectSnapshot,
        ]),
      );
    },
  );

  test('executes tap against a target located by cockpitId', () async {
    final registry = CockpitTargetRegistry(routeName: '/checkout');
    var wasTapped = false;

    registry.register(
      CockpitTarget(
        registrationId: 'submit',
        cockpitId: 'submit_button',
        routeName: '/checkout',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () {
          wasTapped = true;
        },
      ),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-tap',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(cockpitId: 'submit_button'),
      ),
    );

    expect(wasTapped, isTrue);
    expect(result.success, isTrue);
    expect(result.error, isNull);
    expect(
      result.locatorResolution,
      const CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.cockpitId,
        matchedValue: 'submit_button',
      ),
    );
  });

  test(
    'focusTextInput and sendTextInputAction route through onTextInput',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      final requests = <CockpitTextInputRequest>[];

      registry.register(
        CockpitTarget(
          registrationId: 'task-input',
          cockpitId: 'task_input',
          routeName: '/editor',
          supportedCommands: const {
            CockpitCommandType.enterText,
            CockpitCommandType.focusTextInput,
            CockpitCommandType.setTextEditingValue,
            CockpitCommandType.sendTextInputAction,
          },
          onTextInput: requests.add,
        ),
      );

      final executor = InAppCockpitCommandExecutor(registry: registry);

      final focusResult = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-focus',
          commandType: CockpitCommandType.focusTextInput,
          locator: const CockpitLocator(cockpitId: 'task_input'),
        ),
      );
      final actionResult = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-action',
          commandType: CockpitCommandType.sendTextInputAction,
          locator: const CockpitLocator(cockpitId: 'task_input'),
          parameters: const {'inputAction': 'search'},
        ),
      );

      expect(focusResult.success, isTrue);
      expect(actionResult.success, isTrue);
      expect(requests, hasLength(2));
      expect(requests.first.requestFocus, isTrue);
      expect(requests.first.text, isNull);
      expect(requests.last.inputAction, CockpitTextInputAction.search);
    },
  );

  test('setTextEditingValue sends selection and replacement text', () async {
    final registry = CockpitTargetRegistry(routeName: '/editor');
    CockpitTextInputRequest? lastRequest;

    registry.register(
      CockpitTarget(
        registrationId: 'task-input',
        cockpitId: 'task_input',
        routeName: '/editor',
        supportedCommands: const {
          CockpitCommandType.enterText,
          CockpitCommandType.focusTextInput,
          CockpitCommandType.setTextEditingValue,
          CockpitCommandType.sendTextInputAction,
        },
        onTextInput: (request) {
          lastRequest = request;
        },
      ),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-editing-value',
        commandType: CockpitCommandType.setTextEditingValue,
        locator: const CockpitLocator(cockpitId: 'task_input'),
        parameters: const {
          'text': 'Search inbox',
          'selectionBase': 0,
          'selectionExtent': 6,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(lastRequest, isNotNull);
    expect(lastRequest!.text, 'Search inbox');
    expect(lastRequest!.selectionBase, 0);
    expect(lastRequest!.selectionExtent, 6);
  });

  test('dispatches keyboard commands through the key event handler', () async {
    final requests = <CockpitKeyEventRequest>[];

    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/editor'),
      keyEventHandler: (request, type) async {
        requests.add(request);
        return true;
      },
    );

    final downResult = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-key-down',
        commandType: CockpitCommandType.sendKeyDownEvent,
        parameters: const <String, Object?>{
          'logicalKey': 'tab',
          'physicalKey': 'tab',
        },
      ),
    );
    final upResult = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-key-up',
        commandType: CockpitCommandType.sendKeyUpEvent,
        parameters: const <String, Object?>{
          'logicalKey': 'tab',
          'physicalKey': 'tab',
        },
      ),
    );

    expect(downResult.success, isTrue);
    expect(upResult.success, isTrue);
    expect(requests, hasLength(2));
    expect(requests.first.logicalKey, LogicalKeyboardKey.tab);
    expect(requests.first.physicalKey, PhysicalKeyboardKey.tab);
  });

  test('runs semantics-only actions when the target supports them', () async {
    final registry = CockpitTargetRegistry(routeName: '/slider');
    var increased = 0;
    var dismissed = 0;

    registry.register(
      CockpitTarget(
        registrationId: 'stepper',
        keyValue: 'stepper-control',
        routeName: '/slider',
        supportedCommands: const <CockpitCommandType>{
          CockpitCommandType.increase,
          CockpitCommandType.dismiss,
        },
        onSemanticIncrease: () {
          increased += 1;
        },
        onSemanticDismiss: () {
          dismissed += 1;
        },
      ),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);

    final increaseResult = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-increase',
        commandType: CockpitCommandType.increase,
        locator: const CockpitLocator(key: 'stepper-control'),
      ),
    );
    final dismissResult = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-dismiss',
        commandType: CockpitCommandType.dismiss,
        locator: const CockpitLocator(key: 'stepper-control'),
      ),
    );

    expect(increaseResult.success, isTrue);
    expect(dismissResult.success, isTrue);
    expect(increased, 1);
    expect(dismissed, 1);
  });

  test('falls back from cockpitId to text when resolving targets', () async {
    final registry = CockpitTargetRegistry(routeName: '/checkout');
    var tapCount = 0;

    registry.register(
      CockpitTarget(
        registrationId: 'submit',
        text: 'Submit order',
        routeName: '/checkout',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () {
          tapCount += 1;
        },
      ),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-fallback',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(
          cockpitId: 'missing_button',
          fallbacks: [CockpitLocator(text: 'Submit order')],
        ),
      ),
    );

    expect(tapCount, 1);
    expect(result.success, isTrue);
    expect(
      result.locatorResolution,
      const CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.text,
        matchedValue: 'Submit order',
      ),
    );
  });

  test(
    'waits for post-action settling before the next command resolves new route targets',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/home');
      var submittedName = '';

      registry.register(
        CockpitTarget(
          registrationId: 'home.open_form_button',
          cockpitId: 'open_form_button',
          routeName: '/home',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {
            registry.routeName = '/form';
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () async {
          registry.register(
            CockpitTarget(
              registrationId: 'form.name_input',
              cockpitId: 'name_input',
              routeName: '/form',
              supportedCommands: const {CockpitCommandType.enterText},
              onEnterText: (text) {
                submittedName = text;
              },
            ),
          );
        },
      );

      final tapResult = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-open-form',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(cockpitId: 'open_form_button'),
        ),
      );
      final enterTextResult = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-enter-name',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(cockpitId: 'name_input'),
          parameters: const {'text': 'Alice'},
        ),
      );

      expect(tapResult.success, isTrue);
      expect(enterTextResult.success, isTrue);
      expect(submittedName, 'Alice');
    },
  );

  test(
    'waits for a target to appear before failing a control command',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/checkout');
      var tapCount = 0;
      var tickCount = 0;

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () async {},
        waitTickHandler: (duration) async {
          tickCount += 1;
          if (tickCount == 2) {
            registry.register(
              CockpitTarget(
                registrationId: 'create',
                keyValue: 'create-task-button',
                routeName: '/checkout',
                supportedCommands: const {CockpitCommandType.tap},
                onTap: () {
                  tapCount += 1;
                },
              ),
            );
          }
        },
        interactionPolicy: const CockpitInteractionPolicy(
          targetResolveTimeout: Duration(milliseconds: 120),
          targetResolvePollInterval: Duration(milliseconds: 10),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-eventual-target',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(key: 'create-task-button'),
        ),
      );

      expect(result.success, isTrue);
      expect(tapCount, 1);
      expect(tickCount, greaterThanOrEqualTo(2));
    },
  );

  test(
    'waits through an empty route transition before resolving the next target',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      var submittedTitle = '';
      var tickCount = 0;

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () async {},
        waitTickHandler: (duration) async {
          tickCount += 1;
          if (tickCount == 3) {
            registry.register(
              CockpitTarget(
                registrationId: 'editor.title',
                text: 'Task title',
                routeName: '/editor',
                supportedCommands: const {CockpitCommandType.enterText},
                onEnterText: (text) {
                  submittedTitle = text;
                },
              ),
            );
          }
        },
        interactionPolicy: const CockpitInteractionPolicy(
          targetResolveTimeout: Duration(milliseconds: 160),
          targetResolvePollInterval: Duration(milliseconds: 10),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-enter-after-route',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(
            text: 'Task title',
            ancestor: CockpitLocator(route: '/editor'),
          ),
          parameters: const <String, Object?>{'text': 'Release checklist'},
        ),
      );

      expect(result.success, isTrue);
      expect(submittedTitle, 'Release checklist');
      expect(tickCount, greaterThanOrEqualTo(3));
    },
  );

  test(
    'adds a longer post-action pacing delay while recording is active',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/checkout');
      final waitedDurations = <Duration>[];

      registry.register(
        CockpitTarget(
          registrationId: 'submit',
          keyValue: 'submit-button',
          routeName: '/checkout',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {},
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () async {},
        waitTickHandler: (duration) async {
          waitedDurations.add(duration);
        },
        interactionPolicy: const CockpitInteractionPolicy(
          actionVisualDelay: Duration(milliseconds: 24),
          routeTransitionVisualDelay: Duration(milliseconds: 80),
          recordingActionVisualDelay: Duration(milliseconds: 140),
        ),
        isRecordingActive: () => true,
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-paced-tap',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(key: 'submit-button'),
        ),
      );

      expect(result.success, isTrue);
      expect(waitedDurations, contains(const Duration(milliseconds: 140)));
    },
  );

  test('command timeout is a hard boundary around action settling', () async {
    final registry = CockpitTargetRegistry(routeName: '/inbox');
    registry.register(
      CockpitTarget(
        registrationId: 'search',
        text: 'Search title or notes',
        routeName: '/inbox',
        supportedCommands: const <CockpitCommandType>{
          CockpitCommandType.enterText,
        },
        onEnterText: (_) {},
      ),
    );
    final blockedSettler = Completer<void>();
    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      postActionSettler: () => blockedSettler.future,
      waitTickHandler: (_) async {},
    );

    final result = await executor
        .execute(
          CockpitCommand(
            commandId: 'enter-text-blocked-settler',
            commandType: CockpitCommandType.enterText,
            locator: const CockpitLocator(text: 'Search title or notes'),
            parameters: const <String, Object?>{'text': 'query'},
            timeoutMs: 30,
          ),
        )
        .timeout(const Duration(milliseconds: 500));

    expect(result.success, isFalse);
    expect(result.error?.code, CockpitCommandError.timeoutCode);
    expect(result.error?.details['commandId'], 'enter-text-blocked-settler');
    expect(result.error?.details['commandType'], 'enterText');
    expect(result.error?.details['routeName'], '/inbox');
  });

  test('waits briefly for assertText targets after async UI updates', () async {
    final registry = CockpitTargetRegistry(routeName: '/inbox');
    var tickCount = 0;

    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      postActionSettler: () async {},
      waitTickHandler: (duration) async {
        tickCount += 1;
        if (tickCount == 2) {
          registry.register(
            const CockpitTarget(
              registrationId: 'task-row',
              text: 'Async saved task',
              routeName: '/inbox',
            ),
          );
        }
      },
      interactionPolicy: const CockpitInteractionPolicy(
        uiIdleQuietWindow: Duration.zero,
        uiIdleTimeout: Duration.zero,
        targetResolveTimeout: Duration(milliseconds: 120),
        targetResolvePollInterval: Duration(milliseconds: 10),
        actionVisualDelay: Duration.zero,
        routeTransitionVisualDelay: Duration.zero,
        recordingActionVisualDelay: Duration.zero,
      ),
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-assert-created-task',
        commandType: CockpitCommandType.assertText,
        parameters: const <String, Object?>{'text': 'Async saved task'},
      ),
    );

    expect(result.success, isTrue);
    expect(tickCount, greaterThanOrEqualTo(2));
  });

  test(
    'waits briefly for assertVisible locators after async UI updates',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');
      var tickCount = 0;

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () async {},
        waitTickHandler: (duration) async {
          tickCount += 1;
          if (tickCount == 2) {
            registry.register(
              const CockpitTarget(
                registrationId: 'new-row',
                cockpitId: 'created_task_row',
                routeName: '/inbox',
              ),
            );
          }
        },
        interactionPolicy: const CockpitInteractionPolicy(
          uiIdleQuietWindow: Duration.zero,
          uiIdleTimeout: Duration.zero,
          targetResolveTimeout: Duration(milliseconds: 120),
          targetResolvePollInterval: Duration(milliseconds: 10),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-assert-created-row',
          commandType: CockpitCommandType.assertVisible,
          locator: const CockpitLocator(cockpitId: 'created_task_row'),
        ),
      );

      expect(result.success, isTrue);
      expect(tickCount, greaterThanOrEqualTo(2));
    },
  );

  test(
    'waits for pre-action pacing before invoking a resolved tap handler',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/checkout');
      final events = <String>[];

      registry.register(
        CockpitTarget(
          registrationId: 'submit',
          keyValue: 'submit-button',
          routeName: '/checkout',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {
            events.add('tap');
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () async {},
        waitTickHandler: (duration) async {
          events.add('wait:${duration.inMilliseconds}');
        },
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration(milliseconds: 28),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-pre-action-tap',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(key: 'submit-button'),
        ),
      );

      expect(result.success, isTrue);
      expect(events, <String>['wait:28', 'tap']);
    },
  );

  test(
    'uses a longer pre-action pacing delay while recording is active',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/checkout');
      final events = <String>[];

      registry.register(
        CockpitTarget(
          registrationId: 'submit',
          keyValue: 'submit-button',
          routeName: '/checkout',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {
            events.add('tap');
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () async {},
        waitTickHandler: (duration) async {
          events.add('wait:${duration.inMilliseconds}');
        },
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration(milliseconds: 24),
          recordingPreActionVisualDelay: Duration(milliseconds: 120),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
        isRecordingActive: () => true,
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-recording-pre-action',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(key: 'submit-button'),
        ),
      );

      expect(result.success, isTrue);
      expect(events, <String>['wait:120', 'tap']);
    },
  );

  test(
    'returns targetNotFound when no visible target matches the locator',
    () async {
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/checkout'),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-missing',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(cockpitId: 'missing_button'),
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.targetNotFoundCode);
      expect(result.error?.details['visibleTargetSignals'], isNull);
      final visibleTargetHints =
          (result.error?.details['visibleTargetHints'] as List<Object?>?)
              ?.cast<Map<Object?, Object?>>()
              .map((entry) => Map<String, Object?>.from(entry))
              .toList(growable: false) ??
          const <Map<String, Object?>>[];
      expect(visibleTargetHints, isEmpty);
      expect(result.error?.details['visibleTextCandidates'], const <Object?>[]);
      expect(result.error?.details['emptyRouteHint'], contains('run-batch'));
    },
  );

  test(
    'adds a recovery hint when the current route is known but target discovery is still empty',
    () async {
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/editor'),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-editor-transition',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(
            text: 'Task title',
            ancestor: CockpitLocator(route: '/editor'),
          ),
          parameters: const <String, Object?>{'text': 'Hello'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.targetNotFoundCode);
      expect(result.error?.details['routeName'], '/editor');
      expect(result.error?.details['emptyRouteHint'], contains('run-batch'));
    },
  );

  test('returns ambiguousTarget when multiple visible targets match', () async {
    final registry = CockpitTargetRegistry(routeName: '/checkout');

    registry.register(
      CockpitTarget(
        registrationId: 'primary',
        text: 'Continue',
        routeName: '/checkout',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () {},
      ),
    );
    registry.register(
      CockpitTarget(
        registrationId: 'secondary',
        text: 'Continue',
        routeName: '/checkout',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () {},
      ),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-ambiguous',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(text: 'Continue'),
      ),
    );

    expect(result.success, isFalse);
    expect(result.error?.code, CockpitCommandError.ambiguousTargetCode);
    final candidateHints =
        (result.error?.details['candidateHints'] as List<Object?>?)
            ?.cast<Map<Object?, Object?>>()
            .map((entry) => Map<String, Object?>.from(entry))
            .toList(growable: false) ??
        const <Map<String, Object?>>[];
    expect(candidateHints, hasLength(1));
    expect(candidateHints.first['text'], 'Continue');
  });

  test(
    'returns unsupportedCapability when enterText targets a non-input target',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/checkout');

      registry.register(
        CockpitTarget(
          registrationId: 'submit',
          cockpitId: 'submit_button',
          routeName: '/checkout',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {},
        ),
      );

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-input',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(cockpitId: 'submit_button'),
          parameters: const {'text': 'Alice'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.unsupportedCapabilityCode);
    },
  );

  test(
    'enterText prefers an input-capable match when a label shares the same text',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      String? capturedText;

      registry.register(
        CockpitTarget(
          registrationId: 'notes-label',
          text: 'Notes',
          routeName: '/editor',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {},
          geometryProvider: () => const CockpitTargetGeometry(
            left: 0,
            top: 0,
            width: 100,
            height: 20,
            viewportLeft: 0,
            viewportTop: 0,
            viewportWidth: 400,
            viewportHeight: 800,
            viewId: 1,
          ),
        ),
      );
      registry.register(
        CockpitTarget(
          registrationId: 'notes-input',
          text: 'Notes',
          routeName: '/editor',
          supportedCommands: const {CockpitCommandType.enterText},
          onEnterText: (value) {
            capturedText = value;
          },
          geometryProvider: () => const CockpitTargetGeometry(
            left: 0,
            top: 32,
            width: 280,
            height: 120,
            viewportLeft: 0,
            viewportTop: 0,
            viewportWidth: 400,
            viewportHeight: 800,
            viewId: 1,
          ),
        ),
      );

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-notes',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(text: 'Notes'),
          parameters: const {'text': 'Investigate Android notes input'},
        ),
      );

      expect(result.success, isTrue);
      expect(capturedText, 'Investigate Android notes input');
    },
  );

  test(
    'enterText prefers direct text input before semantics setText by default',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      String? directText;
      String? semanticText;

      registry.register(
        CockpitTarget(
          registrationId: 'title-input',
          text: 'Task title',
          routeName: '/editor',
          supportedCommands: const {CockpitCommandType.enterText},
          onTextInput: (request) {
            directText = request.text;
          },
          onSemanticTextInput: (request) {
            semanticText = request.text;
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-title',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(text: 'Task title'),
          parameters: const {'text': 'Release checklist'},
        ),
      );

      expect(result.success, isTrue);
      expect(directText, 'Release checklist');
      expect(semanticText, isNull);
    },
  );

  test(
    'tap uses direct activation for ordinary actionable targets by default',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      var tapCount = 0;
      var gestureCount = 0;

      registry.register(
        CockpitTarget(
          registrationId: 'save-task',
          text: 'Save task',
          routeName: '/editor',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {
            tapCount += 1;
          },
          geometryProvider: () => const CockpitTargetGeometry(
            left: 20,
            top: 720,
            width: 220,
            height: 48,
            viewportLeft: 0,
            viewportTop: 0,
            viewportWidth: 430,
            viewportHeight: 800,
            viewId: 1,
          ),
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        gestureHandler: (_) async {
          gestureCount += 1;
        },
      );
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-save',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'Save task'),
        ),
      );

      expect(result.success, isTrue);
      expect(tapCount, 1);
      expect(gestureCount, 0);
    },
  );

  test(
    'tap can opt into gesture activation when pointer semantics matter',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      var tapCount = 0;
      var gestureCount = 0;

      registry.register(
        CockpitTarget(
          registrationId: 'save-task',
          text: 'Save task',
          routeName: '/editor',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {
            tapCount += 1;
          },
          geometryProvider: () => const CockpitTargetGeometry(
            left: 20,
            top: 720,
            width: 220,
            height: 48,
            viewportLeft: 0,
            viewportTop: 0,
            viewportWidth: 430,
            viewportHeight: 800,
            viewId: 1,
          ),
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        gestureHandler: (_) async {
          gestureCount += 1;
        },
      );
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-save',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'Save task'),
          parameters: const {'activation': 'gesture'},
        ),
      );

      expect(result.success, isTrue);
      expect(tapCount, 0);
      expect(gestureCount, 1);
    },
  );

  test('longPress requires a locator', () async {
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/checkout'),
      gestureHandler: (_) async {},
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-long-press',
        commandType: CockpitCommandType.longPress,
      ),
    );

    expect(result.success, isFalse);
    expect(
      result.error?.code,
      CockpitCommandError.invalidGestureParametersCode,
    );
  });

  test('tap can execute using explicit x and y coordinates', () async {
    CockpitGestureAction? capturedAction;
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/canvas'),
      gestureHandler: (action) async {
        capturedAction = action;
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-tap-at-point',
        commandType: CockpitCommandType.tap,
        parameters: const <String, Object?>{'x': 184.0, 'y': 296.0},
      ),
    );

    expect(result.success, isTrue);
    expect(capturedAction?.type, CockpitGestureActionType.tap);
    expect(capturedAction?.origin, const Offset(184, 296));
  });

  test(
    'drag can start from explicit start coordinates without a locator',
    () async {
      CockpitGestureAction? capturedAction;
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/canvas'),
        gestureHandler: (action) async {
          capturedAction = action;
        },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-drag-from-point',
          commandType: CockpitCommandType.drag,
          parameters: const <String, Object?>{
            'startX': 210.0,
            'startY': 420.0,
            'dx': -96.0,
            'dy': 48.0,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(capturedAction?.type, CockpitGestureActionType.drag);
      expect(capturedAction?.origin, const Offset(210, 420));
      expect(capturedAction?.delta, const Offset(-96, 48));
    },
  );

  test('clearNetworkActivity invokes the injected handler', () async {
    var clearCount = 0;
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/checkout'),
      clearNetworkActivityHandler: () {
        clearCount += 1;
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-clear-network',
        commandType: CockpitCommandType.clearNetworkActivity,
      ),
    );

    expect(result.success, isTrue);
    expect(clearCount, 1);
    expect(result.error, isNull);
  });

  test(
    'waitForNetworkIdle invokes the injected network idle handler',
    () async {
      Duration? capturedQuietWindow;
      Duration? capturedTimeout;
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/checkout'),
        waitForNetworkIdleHandler:
            ({required quietWindow, required timeout}) async {
              capturedQuietWindow = quietWindow;
              capturedTimeout = timeout;
              return true;
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-wait-network-idle',
          commandType: CockpitCommandType.waitForNetworkIdle,
          parameters: const <String, Object?>{'quietWindowMs': 180},
          timeoutMs: 1600,
        ),
      );

      expect(result.success, isTrue);
      expect(capturedQuietWindow, const Duration(milliseconds: 180));
      expect(capturedTimeout, const Duration(milliseconds: 1600));
    },
  );

  test('waitForUiIdle invokes the injected network idle handler', () async {
    Duration? capturedQuietWindow;
    Duration? capturedTimeout;
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/checkout'),
      waitForNetworkIdleHandler:
          ({required quietWindow, required timeout}) async {
            capturedQuietWindow = quietWindow;
            capturedTimeout = timeout;
            return true;
          },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-wait-ui-idle',
        commandType: CockpitCommandType.waitForUiIdle,
        parameters: const <String, Object?>{'quietWindowMs': 240},
        timeoutMs: 900,
      ),
    );

    expect(result.success, isTrue);
    expect(capturedQuietWindow, const Duration(milliseconds: 240));
    expect(capturedTimeout, isNotNull);
    expect(capturedTimeout!.inMilliseconds, inInclusiveRange(880, 900));
  });

  test('waitForUiIdle times out when the app never goes quiet', () async {
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/checkout'),
      waitForNetworkIdleHandler:
          ({required quietWindow, required timeout}) async => false,
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-wait-ui-idle-timeout',
        commandType: CockpitCommandType.waitForUiIdle,
        parameters: const <String, Object?>{'quietWindowMs': 240},
        timeoutMs: 900,
      ),
    );

    expect(result.success, isFalse);
    expect(result.error?.code, CockpitCommandError.timeoutCode);
  });

  test('back invokes the injected navigator handler', () async {
    var backCount = 0;
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/detail'),
      backNavigationHandler: () async {
        backCount += 1;
        return true;
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-back',
        commandType: CockpitCommandType.back,
      ),
    );

    expect(result.success, isTrue);
    expect(backCount, 1);
  });

  test(
    'drag forwards optional holdDurationMs to the gesture handler',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/board');
      registry.register(
        CockpitTarget(
          registrationId: 'queue-card',
          keyValue: 'manual-queue-card-a',
          routeName: '/board',
        ),
      );

      CockpitGestureAction? capturedAction;
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        gestureHandler: (action) async {
          capturedAction = action;
        },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-held-drag',
          commandType: CockpitCommandType.drag,
          locator: const CockpitLocator(key: 'manual-queue-card-a'),
          parameters: const <String, Object?>{
            'dx': -180.0,
            'dy': 0.0,
            'holdDurationMs': 650,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(capturedAction?.type, CockpitGestureActionType.drag);
      expect(capturedAction?.holdDuration, const Duration(milliseconds: 650));
      expect(capturedAction?.delta, const Offset(-180, 0));
    },
  );

  test('rotate forwards rotationRadians to the gesture handler', () async {
    final registry = CockpitTargetRegistry(routeName: '/board');
    registry.register(
      CockpitTarget(
        registrationId: 'planning-surface',
        keyValue: 'planning-surface-canvas',
        routeName: '/board',
      ),
    );

    CockpitGestureAction? capturedAction;
    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      gestureHandler: (action) async {
        capturedAction = action;
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-rotate',
        commandType: CockpitCommandType.rotate,
        locator: const CockpitLocator(key: 'planning-surface-canvas'),
        parameters: const <String, Object?>{
          'rotationRadians': 0.35,
          'startSpan': 88.0,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(capturedAction?.type, CockpitGestureActionType.rotate);
    expect(capturedAction?.rotation, 0.35);
    expect(capturedAction?.startSpan, 88.0);
  });

  test(
    'panZoom validates that at least one gesture dimension changes',
    () async {
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/board'),
        gestureHandler: (_) async {},
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-panzoom-idle',
          commandType: CockpitCommandType.panZoom,
          parameters: const <String, Object?>{
            'scale': 1.0,
            'rotationRadians': 0.0,
            'panDx': 0.0,
            'panDy': 0.0,
          },
        ),
      );

      expect(result.success, isFalse);
      expect(
        result.error?.code,
        CockpitCommandError.invalidGestureParametersCode,
      );
    },
  );

  test(
    'fling can execute without an explicit target using viewport geometry',
    () async {
      CockpitGestureAction? capturedAction;
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/board'),
        gestureHandler: (action) async {
          capturedAction = action;
        },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-fling',
          commandType: CockpitCommandType.fling,
          parameters: const <String, Object?>{
            'dx': 0.0,
            'dy': -420.0,
            'durationMs': 88,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(capturedAction?.type, CockpitGestureActionType.fling);
      expect(capturedAction?.delta, const Offset(0, -420));
      expect(capturedAction?.duration, const Duration(milliseconds: 88));
    },
  );

  test('assertText succeeds when the expected text is visible', () async {
    final registry = CockpitTargetRegistry(routeName: '/success');
    registry.register(
      CockpitTarget(
        registrationId: 'success',
        text: 'Hello, Alice',
        routeName: '/success',
      ),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-assert-text',
        commandType: CockpitCommandType.assertText,
        parameters: const {'text': 'Hello, Alice'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.snapshot?['routeName'], '/success');
  });

  test(
    'assertVisible succeeds for the active route without target lookup',
    () async {
      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/today'),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-assert-route',
          commandType: CockpitCommandType.assertVisible,
          locator: const CockpitLocator(route: '/today'),
        ),
      );

      expect(result.success, isTrue);
      expect(
        result.locatorResolution,
        const CockpitLocatorResolution(
          matchedKind: CockpitLocatorKind.route,
          matchedValue: '/today',
        ),
      );
      expect(result.snapshot?['routeName'], '/today');
    },
  );

  test(
    'assertText succeeds even when the live snapshot would truncate the expected text',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/success');
      for (
        var index = 0;
        index < CockpitTargetRegistry.liveSnapshotTargetLimit + 24;
        index += 1
      ) {
        registry.register(
          CockpitTarget(
            registrationId: 'target-$index',
            text: index == CockpitTargetRegistry.liveSnapshotTargetLimit + 8
                ? 'Work queue'
                : 'Noise target $index',
            routeName: '/success',
          ),
        );
      }

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-assert-truncated-text',
          commandType: CockpitCommandType.assertText,
          parameters: const {'text': 'Work queue'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.snapshot?['routeName'], '/success');
    },
  );

  test('collectSnapshot defaults to baseline diagnostics', () async {
    CockpitSnapshotOptions? usedOptions;
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/diagnostics'),
      snapshotProvider: ({options = const CockpitSnapshotOptions()}) {
        usedOptions = options;
        return CockpitSnapshot(
          routeName: '/diagnostics',
          diagnosticLevel: options.profile,
        );
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-collect',
        commandType: CockpitCommandType.collectSnapshot,
      ),
    );

    expect(result.success, isTrue);
    expect(usedOptions?.profile, CockpitSnapshotProfile.baseline);
    expect(result.snapshot?['diagnosticLevel'], 'baseline');
  });

  test('waitFor succeeds when a target appears before timeout', () async {
    final registry = CockpitTargetRegistry(routeName: '/form');
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        registry.routeName = '/success';
        registry.register(
          CockpitTarget(
            registrationId: 'success',
            cockpitId: 'success_label',
            text: 'Hello, Alice',
            routeName: '/success',
          ),
        );
      }),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-wait-for',
        commandType: CockpitCommandType.waitFor,
        locator: const CockpitLocator(cockpitId: 'success_label'),
        timeoutMs: 500,
      ),
    );

    expect(result.success, isTrue);
    expect(result.locatorResolution?.matchedValue, 'success_label');
    expect(result.snapshot?['routeName'], '/success');
  });

  test(
    'waitFor can require visible targets after the route is reached',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          registry.routeName = '/editor';
        }),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 40), () {
          registry.register(
            CockpitTarget(
              registrationId: 'task-title',
              text: 'Task title',
              routeName: '/editor',
            ),
          );
        }),
      );

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-wait-for-editor-ready',
          commandType: CockpitCommandType.waitFor,
          timeoutMs: 500,
          parameters: const {
            'routeName': '/editor',
            'requireVisibleTargets': true,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.locatorResolution?.matchedKind, CockpitLocatorKind.route);
      expect(result.snapshot?['routeName'], '/editor');
      expect(
        (result.snapshot?['visibleTargets'] as List<Object?>?) ?? const [],
        isNotEmpty,
      );
    },
  );

  test('waitFor route waits for route-ready targets by default', () async {
    final registry = CockpitTargetRegistry(routeName: '/editor');
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 40), () {
        registry.register(
          CockpitTarget(
            registrationId: 'task-title',
            text: 'Task title',
            routeName: '/editor',
          ),
        );
      }),
    );

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-wait-for-editor-default-ready',
        commandType: CockpitCommandType.waitFor,
        timeoutMs: 500,
        parameters: const {'routeName': '/editor'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.locatorResolution?.matchedKind, CockpitLocatorKind.route);
    expect(
      (result.snapshot?['visibleTargets'] as List<Object?>?) ?? const [],
      isNotEmpty,
    );
  });

  test(
    'waitFor command timeout bounds a blocked post-action settler',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');
      final blockedSettler = Completer<void>();
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        postActionSettler: () => blockedSettler.future,
        waitTickHandler: (_) async {},
      );

      final result = await executor
          .execute(
            CockpitCommand(
              commandId: 'wait-for-blocked-settler',
              commandType: CockpitCommandType.waitFor,
              parameters: const <String, Object?>{'routeName': '/detail'},
              timeoutMs: 30,
            ),
          )
          .timeout(const Duration(milliseconds: 500));

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.timeoutCode);
      expect(result.error?.details['routeName'], '/inbox');
    },
  );

  test('waitFor route can explicitly skip target readiness', () async {
    final registry = CockpitTargetRegistry(routeName: '/editor');

    final executor = InAppCockpitCommandExecutor(registry: registry);
    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-wait-for-editor-route-state-only',
        commandType: CockpitCommandType.waitFor,
        timeoutMs: 30,
        parameters: const {
          'routeName': '/editor',
          'requireVisibleTargets': false,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.locatorResolution?.matchedKind, CockpitLocatorKind.route);
    expect((result.snapshot?['visibleTargets'] as List<Object?>?) ?? [], []);
  });

  test(
    'waitFor reports empty route target diagnostics when readiness times out',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-wait-for-editor-targets',
          commandType: CockpitCommandType.waitFor,
          timeoutMs: 30,
          parameters: const {
            'routeName': '/editor',
            'requireVisibleTargets': true,
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.timeoutCode);
      expect(result.error?.details['routeName'], '/editor');
      expect(result.error?.details['visibleTargetCount'], 0);
      expect(result.error?.details['emptyRouteHint'], contains('target'));
      expect(
        result.error?.details['targetDiscoveryDiagnostics'],
        containsPair('currentRouteName', '/editor'),
      );
    },
  );

  test(
    'waitFor route readiness ignores targets discovered only on another route',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor')
        ..discoveredTargetsProvider = () => const <CockpitTarget>[
          CockpitTarget(
            registrationId: 'inbox-new-task',
            text: 'New task',
            routeName: '/inbox',
            supportedCommands: {CockpitCommandType.tap},
          ),
        ];

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-wait-for-editor-strict-targets',
          commandType: CockpitCommandType.waitFor,
          timeoutMs: 30,
          parameters: const {
            'routeName': '/editor',
            'requireVisibleTargets': true,
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.timeoutCode);
      expect(result.error?.details['visibleTargetCount'], 1);
      expect(result.error?.details['routeReadyVisibleTargetCount'], 0);
    },
  );

  testWidgets(
    'tap stabilization waits for route-ready targets instead of inactive fallback targets',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');
      var tickCount = 0;
      registry.discoveredTargetsProvider = () => <CockpitTarget>[
        const CockpitTarget(
          registrationId: 'inbox-new-task',
          text: 'New task',
          routeName: '/inbox',
          supportedCommands: {CockpitCommandType.tap},
        ),
        if (tickCount >= 3)
          const CockpitTarget(
            registrationId: 'editor-title',
            text: 'Task title',
            routeName: '/editor',
          ),
      ];
      registry.register(
        CockpitTarget(
          registrationId: 'open-editor',
          text: 'New task',
          routeName: '/inbox',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {
            registry.routeName = '/editor';
          },
        ),
      );

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        waitTickHandler: (duration) async {
          tickCount += 1;
        },
      );
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'New task'),
        ),
      );

      expect(result.success, isTrue);
      expect(tickCount, greaterThanOrEqualTo(3));
      expect(result.snapshot?['routeName'], '/editor');
      expect(
        ((result.snapshot?['visibleTargets'] as List<Object?>?) ?? const [])
            .cast<Map<Object?, Object?>>()
            .any((target) => target['routeName'] == '/editor'),
        isTrue,
      );
    },
  );

  testWidgets(
    'waitFor can progress under fake async when waitTickHandler pumps frames',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/form');

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          registry.routeName = '/success';
          registry.register(
            CockpitTarget(
              registrationId: 'success',
              keyValue: 'success-key',
              routeName: '/success',
            ),
          );
        }),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        waitTickHandler: tester.pump,
      );
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-wait-for-widget',
          commandType: CockpitCommandType.waitFor,
          locator: const CockpitLocator(key: 'success-key'),
          timeoutMs: 500,
        ),
      );

      expect(result.success, isTrue);
      expect(result.locatorResolution?.matchedValue, 'success-key');
      expect(result.snapshot?['routeName'], '/success');
    },
  );

  testWidgets(
    'tap drives scheduled route frames under flutter_test before waiting for route targets',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      registry.register(
        CockpitTarget(
          registrationId: 'open-editor',
          text: 'Open editor',
          routeName: '/inbox',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () {
            registry.routeName = '/editor';
            registry.register(
              const CockpitTarget(
                registrationId: 'editor-ready',
                keyValue: 'editor-ready',
                routeName: '/editor',
              ),
            );
            WidgetsBinding.instance.scheduleFrame();
          },
        ),
      );

      var tickCount = 0;
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        waitTickHandler: (duration) async {
          tickCount += 1;
          await tester.pump(duration);
        },
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration.zero,
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'Open editor'),
        ),
      );

      expect(result.success, isTrue);
      expect(tickCount, greaterThanOrEqualTo(1));
      expect(result.snapshot?['routeName'], '/editor');
    },
  );

  testWidgets('tap waits for async direct handlers before reporting success', (
    tester,
  ) async {
    final registry = CockpitTargetRegistry(routeName: '/inbox');

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.shrink(),
      ),
    );

    registry.register(
      CockpitTarget(
        registrationId: 'open-editor',
        text: 'Open editor',
        routeName: '/inbox',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () async {
          await Future<void>.delayed(const Duration(milliseconds: 32));
          registry.routeName = '/editor';
          registry.register(
            const CockpitTarget(
              registrationId: 'editor-ready',
              text: 'Editor ready',
              routeName: '/editor',
            ),
          );
        },
      ),
    );

    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      waitTickHandler: tester.pump,
      interactionPolicy: const CockpitInteractionPolicy(
        preActionVisualDelay: Duration.zero,
        actionVisualDelay: Duration.zero,
        routeTransitionVisualDelay: Duration.zero,
        recordingActionVisualDelay: Duration.zero,
      ),
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'open-editor',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(text: 'Open editor'),
      ),
    );

    expect(result.success, isTrue);
    expect(result.snapshot?['routeName'], '/editor');
    expect(
      ((result.snapshot?['visibleTargets'] as List<Object?>?) ?? const [])
          .cast<Map<Object?, Object?>>()
          .any(
            (target) =>
                target['routeName'] == '/editor' &&
                target['text'] == 'Editor ready',
          ),
      isTrue,
    );
  });

  testWidgets(
    'tap continues after a visible commit when an async handler represents a route lifetime',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');
      final routeLifetime = Completer<void>();

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      registry.register(
        CockpitTarget(
          registrationId: 'open-editor',
          text: 'Open editor',
          routeName: '/inbox',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () async {
            registry.routeName = '/editor';
            registry.register(
              const CockpitTarget(
                registrationId: 'editor-ready',
                text: 'Editor ready',
                routeName: '/editor',
              ),
            );
            await routeLifetime.future;
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        waitTickHandler: tester.pump,
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration.zero,
          actionCommitTimeout: Duration(milliseconds: 400),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'Open editor'),
        ),
      );
      addTearDown(routeLifetime.complete);

      expect(result.success, isTrue);
      expect(routeLifetime.isCompleted, isFalse);
      expect(result.snapshot?['routeName'], '/editor');
      expect(
        (result.snapshot?['warnings'] as List<Object?>?) ?? const <Object?>[],
        isEmpty,
      );
    },
  );

  testWidgets(
    'tap action commit waits use lightweight route state before the final snapshot',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');
      final routeLifetime = Completer<void>();
      var snapshotCalls = 0;

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      registry.register(
        CockpitTarget(
          registrationId: 'open-editor',
          text: 'Open editor',
          routeName: '/inbox',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () async {
            registry.routeName = '/editor';
            registry.register(
              const CockpitTarget(
                registrationId: 'editor-ready',
                text: 'Editor ready',
                routeName: '/editor',
              ),
            );
            await routeLifetime.future;
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: ({options = const CockpitSnapshotOptions()}) {
          snapshotCalls += 1;
          return registry.snapshot();
        },
        waitTickHandler: tester.pump,
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration.zero,
          actionCommitTimeout: Duration(milliseconds: 400),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'Open editor'),
        ),
      );
      addTearDown(routeLifetime.complete);

      expect(result.success, isTrue);
      expect(result.snapshot?['routeName'], '/editor');
      expect(snapshotCalls, 1);
    },
  );

  testWidgets('tap route stabilization bounds discovered target probes', (
    tester,
  ) async {
    final registry = CockpitTargetRegistry(routeName: '/inbox');
    final routeLifetime = Completer<void>();
    var discoveryCalls = 0;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.shrink(),
      ),
    );

    registry.discoveredTargetsProvider = () {
      discoveryCalls += 1;
      if (registry.routeName != '/editor') {
        return const <CockpitTarget>[];
      }
      return const <CockpitTarget>[
        CockpitTarget(
          registrationId: 'editor-ready',
          text: 'Editor ready',
          routeName: '/editor',
        ),
      ];
    };
    registry.register(
      CockpitTarget(
        registrationId: 'open-editor',
        text: 'Open editor',
        routeName: '/inbox',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () async {
          registry.routeName = '/editor';
          await routeLifetime.future;
        },
      ),
    );

    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      waitTickHandler: tester.pump,
      interactionPolicy: const CockpitInteractionPolicy(
        preActionVisualDelay: Duration.zero,
        actionCommitTimeout: Duration(milliseconds: 400),
        actionVisualDelay: Duration.zero,
        routeTransitionVisualDelay: Duration.zero,
        recordingActionVisualDelay: Duration.zero,
      ),
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'open-editor',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(text: 'Open editor'),
      ),
    );
    addTearDown(routeLifetime.complete);

    expect(result.success, isTrue);
    expect(result.snapshot?['routeName'], '/editor');
    expect(discoveryCalls, lessThanOrEqualTo(3));
  });

  testWidgets(
    'tap forwards async handler failures that happen before a visible commit',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/inbox');

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      registry.register(
        CockpitTarget(
          registrationId: 'open-editor',
          text: 'Open editor',
          routeName: '/inbox',
          supportedCommands: const {CockpitCommandType.tap},
          onTap: () async {
            await Future<void>.delayed(const Duration(milliseconds: 16));
            throw StateError('save failed');
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        waitTickHandler: tester.pump,
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration.zero,
          actionCommitTimeout: Duration(milliseconds: 400),
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'Open editor'),
        ),
      );

      expect(result.success, isFalse);
      expect(
        result.error?.code,
        CockpitCommandError.gestureExecutionFailedCode,
      );
      expect(result.error?.message, contains('save failed'));
    },
  );

  testWidgets(
    'tap on discovered Material controls commits route pushes before reporting success',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/inbox'),
      );
      addTearDown(FlutterCockpit.dispose);

      final rootKey = GlobalKey<FlutterCockpitRootState>();

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: <NavigatorObserver>[
              FlutterCockpit.navigatorObserver,
            ],
            initialRoute: '/inbox',
            routes: <String, WidgetBuilder>{
              '/inbox': (context) => Scaffold(
                appBar: AppBar(
                  actions: <Widget>[
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () async {
                        await Navigator.of(context).pushNamed('/settings');
                      },
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                ),
                body: Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).pushNamed('/editor');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('New task'),
                  ),
                ),
              ),
              '/editor': (context) => Scaffold(
                appBar: AppBar(),
                body: const TextField(
                  decoration: InputDecoration(labelText: 'Task title'),
                ),
              ),
              '/settings': (context) =>
                  const Scaffold(body: Text('Sync settings')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final executor = InAppCockpitCommandExecutor(
        registry: FlutterCockpit.binding.registry,
        snapshotProvider: rootKey.currentState!.snapshot,
        gestureHandler: rootKey.currentState!.performGesture,
        waitTickHandler: tester.pump,
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration.zero,
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final openEditor = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'New task', route: '/inbox'),
        ),
      );

      expect(openEditor.success, isTrue);
      expect(openEditor.snapshot?['routeName'], '/editor');
      expect(
        ((openEditor.snapshot?['visibleTargets'] as List<Object?>?) ?? const [])
            .cast<Map<Object?, Object?>>()
            .any(
              (target) =>
                  target['routeName'] == '/editor' &&
                  target['text'] == 'Task title',
            ),
        isTrue,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      final openSettings = await executor.execute(
        CockpitCommand(
          commandId: 'open-settings',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(tooltip: 'Settings', route: '/inbox'),
        ),
      );

      expect(openSettings.success, isTrue);
      expect(openSettings.snapshot?['routeName'], '/settings');
      expect(
        ((openSettings.snapshot?['visibleTargets'] as List<Object?>?) ??
                const [])
            .cast<Map<Object?, Object?>>()
            .any(
              (target) =>
                  target['routeName'] == '/settings' &&
                  target['text'] == 'Sync settings',
            ),
        isTrue,
      );
    },
  );

  testWidgets(
    'tap on a route-lifetime Material button reports the pushed route before success',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/inbox'),
      );
      addTearDown(FlutterCockpit.dispose);

      final rootKey = GlobalKey<FlutterCockpitRootState>();
      final navigatorKey = GlobalKey<NavigatorState>();
      var refreshAfterEditor = 0;

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            navigatorObservers: <NavigatorObserver>[
              FlutterCockpit.navigatorObserver,
            ],
            initialRoute: '/inbox',
            routes: <String, WidgetBuilder>{
              '/inbox': (context) => Scaffold(
                appBar: AppBar(
                  actions: <Widget>[
                    TextButton.icon(
                      onPressed: () async {
                        await navigatorKey.currentState!.pushNamed('/editor');
                        refreshAfterEditor += 1;
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('New task'),
                    ),
                  ],
                ),
                body: const Text('Inbox ready'),
              ),
              '/editor': (context) => const Scaffold(
                body: TextField(
                  decoration: InputDecoration(labelText: 'Task title'),
                ),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final executor = InAppCockpitCommandExecutor(
        registry: FlutterCockpit.binding.registry,
        snapshotProvider: rootKey.currentState!.snapshot,
        gestureHandler: rootKey.currentState!.performGesture,
        waitTickHandler: tester.pump,
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration.zero,
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'New task'),
        ),
      );

      expect(result.success, isTrue);
      expect(result.snapshot?['routeName'], '/editor');
      expect(refreshAfterEditor, 0);
    },
  );

  testWidgets(
    'tap uses the real gesture pipeline for discovered Material controls',
    (tester) async {
      FlutterCockpit.initialize(
        const FlutterCockpitConfiguration(initialRouteName: '/inbox'),
      );
      addTearDown(FlutterCockpit.dispose);

      final rootKey = GlobalKey<FlutterCockpitRootState>();
      var sawPointerDown = false;

      await tester.pumpWidget(
        FlutterCockpitRoot(
          key: rootKey,
          child: MaterialApp(
            navigatorObservers: <NavigatorObserver>[
              FlutterCockpit.navigatorObserver,
            ],
            initialRoute: '/inbox',
            routes: <String, WidgetBuilder>{
              '/inbox': (context) => Scaffold(
                body: Center(
                  child: Listener(
                    onPointerDown: (_) {
                      sawPointerDown = true;
                    },
                    child: TextButton(
                      onPressed: () {
                        if (sawPointerDown) {
                          Navigator.of(context).pushNamed('/editor');
                        }
                      },
                      child: const Text('New task'),
                    ),
                  ),
                ),
              ),
              '/editor': (context) =>
                  const Scaffold(body: Text('Editor ready')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final executor = InAppCockpitCommandExecutor(
        registry: FlutterCockpit.binding.registry,
        snapshotProvider: rootKey.currentState!.snapshot,
        gestureHandler: rootKey.currentState!.performGesture,
        waitTickHandler: tester.pump,
        interactionPolicy: const CockpitInteractionPolicy(
          preActionVisualDelay: Duration.zero,
          actionVisualDelay: Duration.zero,
          routeTransitionVisualDelay: Duration.zero,
          recordingActionVisualDelay: Duration.zero,
        ),
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'open-editor',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'New task'),
          parameters: const <String, Object?>{'activation': 'gesture'},
        ),
      );

      expect(result.success, isTrue);
      expect(sawPointerDown, isTrue);
    },
  );

  testWidgets(
    'scrollUntilVisible discovers a lazily built target after scrolling',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/list');

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return CockpitSurface(
              routeName: '/list',
              registry: registry,
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView.builder(
                    itemCount: 40,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        height: 96,
                        child: ListTile(
                          key: ValueKey<String>('task-$index'),
                          onTap: () {},
                          title: Text(
                            'Task $index',
                            key: ValueKey<String>('task-label-$index'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        registry.resolve(const CockpitLocator(key: 'task-39')).isSuccess,
        isFalse,
      );

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) {
              return surfaceState.scrollByViewport(
                reverse: reverse,
                viewportFraction: viewportFraction,
                scrollableKey: scrollableKey,
                duration: duration,
                gestureProfile: gestureProfile,
                continuous: continuous,
                postScrollEnsureVisible: postScrollEnsureVisible,
              );
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-to-task-39',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(key: 'task-39'),
          parameters: const <String, Object?>{
            'maxScrolls': 20,
            'viewportFraction': 0.9,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.locatorResolution?.matchedKind, CockpitLocatorKind.key);
      expect(result.locatorResolution?.matchedValue, 'task-39');
      expect(
        registry.resolve(const CockpitLocator(key: 'task-39')).isSuccess,
        isTrue,
      );
    },
  );

  testWidgets('scrollUntilVisible includes after-action screenshot evidence', (
    tester,
  ) async {
    final registry = CockpitTargetRegistry(routeName: '/list');
    var capturedRequestName = '';

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        builder: (context, child) {
          return CockpitSurface(
            routeName: '/list',
            registry: registry,
            child: Material(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: ListView.builder(
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height: 96,
                      child: ListTile(
                        key: ValueKey<String>('evidence-task-$index'),
                        onTap: () {},
                        title: Text('Evidence Task $index'),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final surfaceState = tester.state<CockpitSurfaceState>(
      find.byType(CockpitSurface),
    );
    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      snapshotProvider: surfaceState.snapshot,
      captureHandler: (request) async {
        capturedRequestName = request.name;
        return CockpitCaptureResult(
          screenshot: CockpitCapturedScreenshot(
            artifact: CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/${request.name}.png',
            ),
            bytes: Uint8List.fromList(const <int>[137, 80, 78, 71]),
            snapshot: surfaceState.snapshot(),
          ),
          requestedProfile: CockpitCaptureProfile.acceptance,
          resolvedCaptureKind: CockpitCaptureKind.flutterView,
        );
      },
      postActionSettler: () async {
        await tester.pump();
        await tester.pump();
      },
      scrollStepHandler:
          ({
            required reverse,
            required viewportFraction,
            scrollableKey,
            targetLocator,
            scrollableLocator,
            required duration,
            required gestureProfile,
            required continuous,
            required postScrollEnsureVisible,
          }) {
            return surfaceState.scrollByViewport(
              reverse: reverse,
              viewportFraction: viewportFraction,
              scrollableKey: scrollableKey,
              duration: duration,
              gestureProfile: gestureProfile,
              continuous: continuous,
              postScrollEnsureVisible: postScrollEnsureVisible,
            );
          },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'scroll-evidence-task-29',
        commandType: CockpitCommandType.scrollUntilVisible,
        locator: const CockpitLocator(key: 'evidence-task-29'),
        capturePolicy: CockpitCapturePolicy.afterAction,
        captureFailurePolicy: CockpitCaptureFailurePolicy.degradeCommand,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.afterAction,
          name: 'scroll-evidence-task-29',
          includeSnapshot: true,
          attachToStep: true,
          snapshotOptions: CockpitSnapshotOptions.live(),
        ),
        parameters: const <String, Object?>{
          'maxScrolls': 20,
          'viewportFraction': 0.9,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(capturedRequestName, 'scroll-evidence-task-29');
    expect(result.artifacts.map((artifact) => artifact.relativePath), [
      'screenshots/scroll-evidence-task-29.png',
    ]);
    expect(result.resolvedCaptureKind, CockpitCaptureKind.flutterView);
  });

  testWidgets(
    'scrollUntilVisible succeeds when a keyed target becomes visible on the final scrollable viewport',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/settings');

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return CockpitSurface(
              routeName: '/settings',
              registry: registry,
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView(
                    children: <Widget>[
                      const SizedBox(height: 900),
                      FilledButton(
                        key: const ValueKey<String>(
                          'settings-debug-log-button',
                        ),
                        onPressed: () {},
                        child: const Text('Emit debug log'),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) {
              return surfaceState.scrollByViewport(
                reverse: reverse,
                viewportFraction: viewportFraction,
                scrollableKey: scrollableKey,
                targetLocator: targetLocator,
                scrollableLocator: scrollableLocator,
                duration: duration,
                gestureProfile: gestureProfile,
                continuous: continuous,
                postScrollEnsureVisible: postScrollEnsureVisible,
              );
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-to-debug-log-button',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(
            key: 'settings-debug-log-button',
            ancestor: CockpitLocator(route: '/settings'),
          ),
          parameters: const <String, Object?>{
            'maxScrolls': 3,
            'viewportFraction': 0.65,
            'scrollableLocator': <String, Object?>{
              'type': 'ListView',
              'route': '/settings',
            },
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.locatorResolution?.matchedKind, CockpitLocatorKind.key);
      expect(
        result.locatorResolution?.matchedValue,
        'settings-debug-log-button',
      );
    },
  );

  testWidgets(
    'scrollUntilVisible stops probing before a newly visible target is pushed under a sticky overlay',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/settings');

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return Center(
              child: SizedBox(
                width: 320,
                height: 320,
                child: CockpitSurface(
                  routeName: '/settings',
                  registry: registry,
                  child: Material(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Stack(
                        children: <Widget>[
                          ListView(
                            key: const ValueKey<String>('settings-list'),
                            padding: EdgeInsets.zero,
                            children: <Widget>[
                              SizedBox(height: 330),
                              SizedBox(
                                height: 24,
                                child: FilledButton(
                                  key: const ValueKey<String>(
                                    'settings-danger-zone',
                                  ),
                                  onPressed: () {},
                                  child: const Text('Danger zone'),
                                ),
                              ),
                              const SizedBox(height: 600),
                            ],
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () {},
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                height: 96,
                                color: const Color(0xFF101214),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) {
              return surfaceState.scrollByViewport(
                reverse: reverse,
                viewportFraction: viewportFraction,
                scrollableKey: scrollableKey,
                targetLocator: targetLocator,
                scrollableLocator: scrollableLocator,
                duration: duration,
                gestureProfile: gestureProfile,
                continuous: continuous,
                postScrollEnsureVisible: postScrollEnsureVisible,
              );
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-to-danger-zone-before-overlay',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(
            key: 'settings-danger-zone',
            ancestor: CockpitLocator(route: '/settings'),
          ),
          parameters: const <String, Object?>{
            'maxScrolls': 1,
            'viewportFraction': 0.8,
            'scrollableLocator': <String, Object?>{
              'key': 'settings-list',
              'type': 'ListView',
              'route': '/settings',
            },
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.locatorResolution?.matchedKind, CockpitLocatorKind.key);
      expect(result.locatorResolution?.matchedValue, 'settings-danger-zone');
    },
  );

  testWidgets(
    'scrollUntilVisible falls back to the opposite direction after hitting the wrong scroll boundary',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/settings');
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return SizedBox(
              width: 320,
              height: 320,
              child: CockpitSurface(
                routeName: '/settings',
                registry: registry,
                child: Material(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: ListView.builder(
                      key: const ValueKey<String>('settings-list'),
                      controller: controller,
                      itemCount: 24,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          height: 96,
                          child: ListTile(
                            key: ValueKey<String>('settings-item-$index'),
                            title: Text('Settings item $index'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) {
              return surfaceState.scrollByViewport(
                reverse: reverse,
                viewportFraction: viewportFraction,
                scrollableKey: scrollableKey,
                targetLocator: targetLocator,
                scrollableLocator: scrollableLocator,
                duration: duration,
                gestureProfile: gestureProfile,
                continuous: continuous,
                postScrollEnsureVisible: postScrollEnsureVisible,
              );
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-recover-wrong-direction',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(
            key: 'settings-item-18',
            ancestor: CockpitLocator(route: '/settings'),
          ),
          parameters: const <String, Object?>{
            'maxScrolls': 3,
            'viewportFraction': 0.65,
            'scrollableLocator': <String, Object?>{
              'key': 'settings-list',
              'type': 'ListView',
              'route': '/settings',
            },
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.locatorResolution?.matchedKind, CockpitLocatorKind.key);
      expect(result.locatorResolution?.matchedValue, 'settings-item-18');
    },
  );

  testWidgets(
    'scrollUntilVisible treats visible passive text as visible when its ancestor owns the hit',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/stack');

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return CockpitSurface(
              routeName: '/stack',
              registry: registry,
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {},
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(24, 420, 24, 24),
                          child: Text('Acceptance bundles'),
                        ),
                      ),
                      const SizedBox(height: 320),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) async {
              return const CockpitScrollStepResult(didScroll: false);
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-passive-text-hit-owned-by-ancestor',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(text: 'Acceptance bundles'),
          parameters: const <String, Object?>{'maxScrolls': 1},
        ),
      );

      expect(result.success, isTrue);
    },
  );

  testWidgets(
    'scrollUntilVisible treats visible passive row text as visible without a hit-testable ancestor',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/stack');

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return CockpitSurface(
              routeName: '/stack',
              registry: registry,
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView(
                    children: const <Widget>[
                      SizedBox(height: 420),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: Text('Acceptance bundles')),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text('Review screenshots and recordings.'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 320),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) async {
              return const CockpitScrollStepResult(didScroll: false);
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-passive-row-text',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(text: 'Acceptance bundles'),
          parameters: const <String, Object?>{'maxScrolls': 1},
        ),
      );

      expect(result.success, isTrue);
    },
  );

  testWidgets(
    'scrollUntilVisible does not treat text as visible when an overlay covers it',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/stack');

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return CockpitSurface(
              routeName: '/stack',
              registry: registry,
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Stack(
                    children: <Widget>[
                      ListView(
                        children: const <Widget>[
                          SizedBox(height: 420),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text('Acceptance bundles'),
                          ),
                          SizedBox(height: 400),
                        ],
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () {},
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 180,
                            color: const Color(0xFF101214),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      expect(
        surfaceState.registry.visibleTargets.any(
          (target) => target.text == 'Acceptance bundles',
        ),
        isTrue,
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) async {
              return const CockpitScrollStepResult(didScroll: false);
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-covered-target',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(text: 'Acceptance bundles'),
          parameters: const <String, Object?>{'maxScrolls': 1},
        ),
      );

      expect(result.success, isFalse);
    },
  );

  testWidgets(
    'scrollUntilVisible failure includes scroll context and visible scrollables',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/list');

      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          builder: (context, child) {
            return CockpitSurface(
              routeName: '/list',
              registry: registry,
              child: Material(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView(
                    key: const ValueKey<String>('task-list'),
                    children: List<Widget>.generate(
                      12,
                      (index) => SizedBox(
                        height: 96,
                        child: ListTile(title: Text('Task $index')),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) async {
              return const CockpitScrollStepResult(didScroll: false);
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-failure-with-context',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(key: 'task-99'),
          parameters: const <String, Object?>{
            'maxScrolls': 2,
            'scrollableLocator': <String, Object?>{
              'key': 'task-list',
              'type': 'ListView',
            },
          },
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.targetNotFoundCode);
      expect(result.error?.details['scrollAttempts'], 1);
      expect(result.error?.details['scrollsPerformed'], 0);
      expect(result.error?.details['scrollableLocator'], <String, Object?>{
        'key': 'task-list',
        'type': 'ListView',
        'fallbacks': <Object?>[],
      });
      final visibleScrollables =
          (result.error?.details['visibleScrollables'] as List<Object?>?)
              ?.cast<Map<Object?, Object?>>()
              .map((entry) => Map<String, Object?>.from(entry))
              .toList(growable: false) ??
          const <Map<String, Object?>>[];
      expect(visibleScrollables, contains(containsPair('key', 'task-list')));
    },
  );

  testWidgets('scrollUntilVisible applies visual pacing between scroll steps', (
    tester,
  ) async {
    final registry = CockpitTargetRegistry(routeName: '/list');
    final waitedDurations = <Duration>[];
    var scrollCount = 0;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox.shrink(),
      ),
    );

    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      postActionSettler: () async {},
      waitTickHandler: (duration) async {
        waitedDurations.add(duration);
      },
      interactionPolicy: const CockpitInteractionPolicy(
        preActionVisualDelay: Duration.zero,
        actionVisualDelay: Duration.zero,
        routeTransitionVisualDelay: Duration.zero,
        recordingActionVisualDelay: Duration(milliseconds: 90),
      ),
      isRecordingActive: () => true,
      scrollStepHandler:
          ({
            required reverse,
            required viewportFraction,
            scrollableKey,
            targetLocator,
            scrollableLocator,
            required duration,
            required gestureProfile,
            required continuous,
            required postScrollEnsureVisible,
          }) async {
            scrollCount += 1;
            if (scrollCount == 1) {
              registry.register(
                CockpitTarget(
                  registrationId: 'task-39',
                  keyValue: 'task-39',
                  routeName: '/list',
                ),
              );
            }
            return const CockpitScrollStepResult(didScroll: true);
          },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'scroll-paced',
        commandType: CockpitCommandType.scrollUntilVisible,
        locator: const CockpitLocator(key: 'task-39'),
        parameters: const <String, Object?>{'maxScrolls': 3},
      ),
    );

    expect(result.success, isTrue);
    expect(scrollCount, 1);
    expect(waitedDurations, contains(const Duration(milliseconds: 90)));
  });

  test('scrollUntilVisible forwards continuous scroll parameters', () async {
    final registry = CockpitTargetRegistry(routeName: '/list');
    var capturedDuration = Duration.zero;
    var capturedProfile = CockpitGestureProfile.fast;
    var capturedContinuous = false;
    var capturedEnsureVisible = false;

    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      scrollStepHandler:
          ({
            required reverse,
            required viewportFraction,
            scrollableKey,
            targetLocator,
            scrollableLocator,
            required duration,
            required gestureProfile,
            required continuous,
            required postScrollEnsureVisible,
          }) async {
            capturedDuration = duration;
            capturedProfile = gestureProfile;
            capturedContinuous = continuous;
            capturedEnsureVisible = postScrollEnsureVisible;
            registry.register(
              CockpitTarget(
                registrationId: 'task-39',
                keyValue: 'task-39',
                routeName: '/list',
              ),
            );
            return const CockpitScrollStepResult(didScroll: true);
          },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'scroll-forwarding',
        commandType: CockpitCommandType.scrollUntilVisible,
        locator: const CockpitLocator(key: 'task-39'),
        parameters: const <String, Object?>{
          'durationPerStepMs': 360,
          'gestureProfile': 'precise',
          'continuous': true,
          'postScrollEnsureVisible': false,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(capturedDuration, const Duration(milliseconds: 360));
    expect(capturedProfile, CockpitGestureProfile.precise);
    expect(capturedContinuous, isTrue);
    expect(capturedEnsureVisible, isFalse);
  });

  test(
    'scrollUntilVisible forwards reveal alignment parameters to ensureVisible',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/list');
      CockpitRevealAlignment? capturedAlignment;
      double? capturedPadding;

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) async {
              return const CockpitScrollStepResult(didScroll: false);
            },
        ensureVisibleHandler:
            ({
              required locator,
              required duration,
              required alignment,
              required padding,
            }) async {
              capturedAlignment = alignment;
              capturedPadding = padding;
              registry.register(
                CockpitTarget(
                  registrationId: 'task-39',
                  keyValue: 'task-39',
                  routeName: '/list',
                ),
              );
              return true;
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-forward-reveal-alignment',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(key: 'task-39'),
          parameters: const <String, Object?>{
            'revealAlignment': 'center',
            'revealPaddingPx': 36,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(capturedAlignment, CockpitRevealAlignment.center);
      expect(capturedPadding, 36);
    },
  );

  test(
    'scrollUntilVisible repositions an already visible target when reveal alignment is requested',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/list');
      CockpitRevealAlignment? capturedAlignment;

      registry.register(
        CockpitTarget(
          registrationId: 'task-0',
          keyValue: 'task-0',
          routeName: '/list',
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        scrollStepHandler:
            ({
              required reverse,
              required viewportFraction,
              scrollableKey,
              targetLocator,
              scrollableLocator,
              required duration,
              required gestureProfile,
              required continuous,
              required postScrollEnsureVisible,
            }) async {
              return const CockpitScrollStepResult(didScroll: false);
            },
        ensureVisibleHandler:
            ({
              required locator,
              required duration,
              required alignment,
              required padding,
            }) async {
              capturedAlignment = alignment;
              return true;
            },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'scroll-visible-realign',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(key: 'task-0'),
          parameters: const <String, Object?>{'revealAlignment': 'center'},
        ),
      );

      expect(result.success, isTrue);
      expect(capturedAlignment, CockpitRevealAlignment.center);
    },
  );

  testWidgets(
    'tap does not reject a visible text field when the probe stays inside its bounds',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/search');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CockpitSurface(
            routeName: '/search',
            registry: registry,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: TextField(
                    key: const ValueKey<String>('task-search-input'),
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Search title or notes',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        gestureHandler: surfaceState.performGesture,
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-tap-search-input',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(key: 'task-search-input'),
        ),
      );
      await tester.pump();

      expect(result.success, isTrue);
      expect(focusNode.hasFocus, isTrue);
    },
  );

  testWidgets('tap warns but continues when hitTestMissPolicy is warn', (
    tester,
  ) async {
    final registry = CockpitTargetRegistry(routeName: '/overlay');
    var gestureCount = 0;

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: SizedBox(
            width: 320,
            height: 240,
            child: Stack(
              children: <Widget>[
                Center(
                  child: SizedBox(
                    key: ValueKey<String>('occluded-target'),
                    width: 140,
                    height: 72,
                  ),
                ),
                Positioned.fill(child: ColoredBox(color: Color(0xFF202020))),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(
      find.byKey(const ValueKey<String>('occluded-target')),
    );
    registry.register(
      CockpitTarget(
        registrationId: 'occluded-target',
        keyValue: 'occluded-target',
        routeName: '/overlay',
        supportedCommands: const {CockpitCommandType.tap},
        diagnosticNodeProvider: () => element,
      ),
    );

    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      gestureHandler: (_) async {
        gestureCount += 1;
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-hit-test-warn',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(key: 'occluded-target'),
        parameters: const <String, Object?>{'hitTestMissPolicy': 'warn'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.error, isNull);
    expect(gestureCount, 1);
    expect(result.degradationReason, 'hitTestMissWarning');
    expect(
      (result.snapshot?['warnings'] as List<Object?>?)?.isNotEmpty,
      isTrue,
    );
  });

  testWidgets(
    'tap fails when hitTestMissPolicy is fail and the target is occluded',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/overlay');
      var gestureCount = 0;

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: SizedBox(
              width: 320,
              height: 240,
              child: Stack(
                children: <Widget>[
                  Center(
                    child: SizedBox(
                      key: ValueKey<String>('blocked-target'),
                      width: 140,
                      height: 72,
                    ),
                  ),
                  Positioned.fill(child: ColoredBox(color: Color(0xFF202020))),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(
        find.byKey(const ValueKey<String>('blocked-target')),
      );
      registry.register(
        CockpitTarget(
          registrationId: 'blocked-target',
          keyValue: 'blocked-target',
          routeName: '/overlay',
          supportedCommands: const {CockpitCommandType.tap},
          diagnosticNodeProvider: () => element,
        ),
      );

      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        gestureHandler: (_) async {
          gestureCount += 1;
        },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-hit-test-fail',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(key: 'blocked-target'),
          parameters: const <String, Object?>{'hitTestMissPolicy': 'fail'},
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, CockpitCommandError.targetNotHittableCode);
      expect(gestureCount, 0);
    },
  );

  test(
    'enterText forwards rich text-input requests to target handlers',
    () async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      CockpitTextInputRequest? request;

      registry.register(
        CockpitTarget(
          registrationId: 'search-input',
          keyValue: 'search-input',
          routeName: '/editor',
          supportedCommands: const {CockpitCommandType.enterText},
          onTextInput: (value) {
            request = value;
          },
        ),
      );

      final executor = InAppCockpitCommandExecutor(registry: registry);
      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-rich-enter-text',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(key: 'search-input'),
          parameters: const <String, Object?>{
            'text': 'Alice',
            'selectionBase': 1,
            'selectionExtent': 3,
            'inputAction': 'search',
            'requestFocus': false,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(
        request,
        const CockpitTextInputRequest(
          text: 'Alice',
          selectionBase: 1,
          selectionExtent: 3,
          inputAction: CockpitTextInputAction.search,
          requestFocus: false,
        ),
      );
    },
  );

  testWidgets(
    'enterText can submit a next action and move focus to the next field',
    (tester) async {
      final registry = CockpitTargetRegistry(routeName: '/editor');
      final firstFocus = FocusNode();
      final secondFocus = FocusNode();
      addTearDown(firstFocus.dispose);
      addTearDown(secondFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CockpitSurface(
            routeName: '/editor',
            registry: registry,
            child: Scaffold(
              body: Column(
                children: <Widget>[
                  TextField(
                    key: const ValueKey<String>('first-input'),
                    focusNode: firstFocus,
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    key: const ValueKey<String>('second-input'),
                    focusNode: secondFocus,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        postActionSettler: () async {
          await tester.pump();
          await tester.pump();
        },
        gestureHandler: surfaceState.performGesture,
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-input-next',
          commandType: CockpitCommandType.enterText,
          locator: const CockpitLocator(key: 'first-input'),
          parameters: const <String, Object?>{
            'text': 'Alpha',
            'inputAction': 'next',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(result.success, isTrue);
      expect(firstFocus.hasFocus, isFalse);
      expect(secondFocus.hasFocus, isTrue);
      expect(find.text('Alpha'), findsOneWidget);
    },
  );

  test(
    'captureScreenshot waits for post-action settling before capturing',
    () async {
      var settled = false;
      Duration? capturedQuietWindow;
      Duration? capturedTimeout;

      final executor = InAppCockpitCommandExecutor(
        registry: CockpitTargetRegistry(routeName: '/success'),
        postActionSettler: () async {
          settled = true;
        },
        waitForNetworkIdleHandler:
            ({required quietWindow, required timeout}) async {
              capturedQuietWindow = quietWindow;
              capturedTimeout = timeout;
              return true;
            },
        captureHandler: (request) async {
          expect(settled, isTrue);
          expect(
            request.snapshotOptions?.profile,
            CockpitSnapshotProfile.investigate,
          );
          return CockpitCaptureResult(
            screenshot: CockpitCapturedScreenshot(
              artifact: const CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/acceptance.png',
              ),
              bytes: Uint8List.fromList(const <int>[137, 80, 78, 71]),
              snapshot: CockpitSnapshot(routeName: '/success'),
            ),
            requestedProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.nativeAcceptance,
          );
        },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
            includeSnapshot: true,
            attachToStep: true,
          ),
        ),
      );

      expect(result.success, isTrue);
      expect(
        result.artifacts.single.relativePath,
        'screenshots/acceptance.png',
      );
      expect(capturedQuietWindow, const Duration(milliseconds: 96));
      expect(capturedTimeout, isNotNull);
      expect(capturedTimeout!.inMilliseconds, inInclusiveRange(1560, 1600));
    },
  );

  test('auto after-action capture failure does not fail the command', () async {
    final registry = CockpitTargetRegistry(routeName: '/editor');
    var tapCount = 0;
    registry.register(
      CockpitTarget(
        registrationId: 'save-button',
        keyValue: 'save-button',
        routeName: '/editor',
        supportedCommands: const {CockpitCommandType.tap},
        onTap: () {
          tapCount += 1;
        },
      ),
    );
    final executor = InAppCockpitCommandExecutor(
      registry: registry,
      captureHandler: (_) async {
        throw StateError('screenshot surface unavailable');
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-save',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(key: 'save-button'),
        capturePolicy: CockpitCapturePolicy.afterAction,
        captureFailurePolicy: CockpitCaptureFailurePolicy.degradeCommand,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.afterAction,
          name: 'cmd-save',
          includeSnapshot: true,
          attachToStep: true,
          snapshotOptions: CockpitSnapshotOptions.live(),
        ),
      ),
    );

    expect(tapCount, 1);
    expect(result.success, isTrue);
    expect(result.artifacts, isEmpty);
    expect(result.usedCaptureFallback, isTrue);
    expect(result.degradationReason, contains('afterActionCaptureFailed'));
    expect(result.error, isNull);
  });

  test('captureScreenshot forwards explicit snapshot options', () async {
    final executor = InAppCockpitCommandExecutor(
      registry: CockpitTargetRegistry(routeName: '/success'),
      captureHandler: (request) async {
        expect(
          request.snapshotOptions?.profile,
          CockpitSnapshotProfile.investigate,
        );
        return CockpitCaptureResult(
          screenshot: CockpitCapturedScreenshot(
            artifact: const CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/investigate.png',
            ),
            bytes: Uint8List.fromList(const <int>[137, 80, 78, 71]),
            snapshot: CockpitSnapshot(
              routeName: '/success',
              diagnosticLevel:
                  request.snapshotOptions?.profile ??
                  CockpitSnapshotProfile.live,
            ),
          ),
          requestedProfile: CockpitCaptureProfile.diagnostic,
          resolvedCaptureKind: CockpitCaptureKind.flutterView,
        );
      },
    );

    final result = await executor.execute(
      CockpitCommand(
        commandId: 'cmd-capture-investigate',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.assertionFailure,
          name: 'investigate',
          includeSnapshot: true,
          attachToStep: true,
          snapshotOptions: CockpitSnapshotOptions.investigate(),
        ),
      ),
    );

    expect(result.success, isTrue);
    expect(result.snapshot?['diagnosticLevel'], 'investigate');
  });
}
