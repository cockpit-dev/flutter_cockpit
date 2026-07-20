import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('cockpit.foundation/v2 models', () {
    test('resource and discovery contracts round-trip', () {
      final startedAt = DateTime.utc(2026, 7, 20);
      final server = CockpitServerInfo(
        instanceId: 'supervisorA',
        apiVersion: CockpitApiVersion(major: 2, minor: 1),
        engineVersion: '2.0.0',
        startedAt: startedAt,
        features: _features(),
      );
      _expectRoundTrip(server, CockpitServerInfo.fromJson);
      final negotiation = CockpitProtocolNegotiator.negotiate(
        request: CockpitNegotiationRequest(
          apiVersion: CockpitApiVersion(major: 2, minor: 1),
          requiredFeatures: <String>[
            CockpitFoundationFeature.additiveResponseFields.id,
          ],
        ),
        server: server,
      );
      _expectRoundTrip(negotiation, CockpitNegotiationResult.fromJson);

      final root = CockpitRootResource(
        rootId: 'rootA',
        canonicalPath: '/tmp/cockpit-root',
        filesystemIdentity: 'dev:1:inode:2',
        state: CockpitRootState.active,
        registeredAt: startedAt,
        updatedAt: startedAt,
      );
      _expectRoundTrip(root, CockpitRootResource.fromJson);
      _expectRoundTrip(
        CockpitRootRegistration(
          path: '/tmp/cockpit-root',
          label: 'Development',
        ),
        CockpitRootRegistration.fromJson,
      );
      _expectRoundTrip(
        CockpitRootRemoval(force: true, drainTimeoutMs: 1000),
        CockpitRootRemoval.fromJson,
      );

      final marker = CockpitWorkspaceMarker(
        workspaceId: 'workspaceA',
        projectId: 'projectA',
        checkoutId: 'checkoutA',
        createdAt: startedAt,
      );
      _expectRoundTrip(marker, CockpitWorkspaceMarker.fromJson);
      final workspace = CockpitWorkspaceResource(
        workspaceId: marker.workspaceId,
        projectId: marker.projectId,
        checkoutId: marker.checkoutId,
        rootId: root.rootId,
        canonicalPath: '/tmp/cockpit-root/app',
        filesystemIdentity: 'dev:1:inode:3',
        state: CockpitWorkspaceState.active,
        registeredAt: startedAt,
        updatedAt: startedAt,
      );
      _expectRoundTrip(workspace, CockpitWorkspaceResource.fromJson);
      _expectRoundTrip(
        CockpitWorkspaceRegistration(
          rootId: root.rootId,
          path: workspace.canonicalPath,
        ),
        CockpitWorkspaceRegistration.fromJson,
      );
      _expectRoundTrip(
        CockpitWorkspaceRebind(
          path: '/tmp/cockpit-root/moved-app',
          expectedCheckoutId: marker.checkoutId,
        ),
        CockpitWorkspaceRebind.fromJson,
      );
      _expectRoundTrip(
        CockpitWorkspaceRemoval(drainTimeoutMs: 2500),
        CockpitWorkspaceRemoval.fromJson,
      );

      final document = CockpitDocumentResource(
        documentId: 'documentA',
        workspaceId: workspace.workspaceId,
        relativePath: 'test/e2e/login.cockpit.yaml',
        sha256: _hash('a'),
        modifiedAt: startedAt,
        cases: <CockpitCaseIndexEntry>[
          CockpitCaseIndexEntry(caseId: 'loginCase', title: 'Login'),
        ],
      );
      _expectRoundTrip(document, CockpitDocumentResource.fromJson);
      final reference = CockpitIndexedCaseReference(
        documentId: document.documentId,
        caseId: document.cases.single.caseId,
        documentSha256: document.sha256,
      );
      _expectRoundTrip(reference, CockpitIndexedCaseReference.fromJson);
      _expectRoundTrip(
        CockpitDocumentValidationRequest(
          format: CockpitDocumentFormat.yaml,
          sourceText: '',
          relativePath: document.relativePath,
        ),
        CockpitDocumentValidationRequest.fromJson,
      );

      final descriptor = _runDescriptor();
      _expectRoundTrip(descriptor, CockpitOperationDescriptor.fromJson);
      final capabilities = CockpitCapabilityDocument(
        apiVersion: server.apiVersion,
        features: server.features,
        operations: <CockpitOperationDescriptor>[descriptor],
        resources: <CockpitResourceDescriptor>[
          CockpitResourceDescriptor(
            kind: 'workspace.runs',
            scope: CockpitOperationScope.workspace,
            uriTemplate: '/api/v2/workspaces/{workspaceId}/runs',
            mediaType: 'application/json',
          ),
        ],
      );
      _expectRoundTrip(capabilities, CockpitCapabilityDocument.fromJson);
      final page = CockpitPage<CockpitWorkspaceResource>(
        items: <CockpitWorkspaceResource>[workspace],
        nextCursor: 'bmV4dA',
        totalCount: 2,
      );
      final pageJson = page.toJson((item) => item.toJson());
      expect(
        CockpitPage.fromJson<CockpitWorkspaceResource>(
          pageJson,
          (value, path, policy) => CockpitWorkspaceResource.fromJson(
            value,
            path: path,
            decodePolicy: policy,
          ),
        ).toJson((item) => item.toJson()),
        pageJson,
      );
    });

    test(
      'execution, error, event, artifact, and lease contracts round-trip',
      () {
        final submittedAt = DateTime.utc(2026, 7, 20, 1);
        final startedAt = submittedAt.add(const Duration(seconds: 1));
        final finishedAt = startedAt.add(const Duration(seconds: 2));
        final testCase = _testCase();
        _expectRoundTrip(
          CockpitDocumentValidationResult(
            valid: true,
            sourceSha256: _hash('a'),
            testCase: testCase,
          ),
          CockpitDocumentValidationResult.fromJson,
        );

        final submission = CockpitRunSubmission(
          workspaceId: 'workspaceA',
          source: CockpitInlineCaseSource(
            testCase: testCase,
            sourceSha256: _hash('a'),
          ),
          idempotencyKey: CockpitIdempotencyKey('run:login:1'),
          inputs: const <String, Object?>{'username': 'tester@example.com'},
          targetId: 'deviceA',
        );
        _expectRoundTrip(submission, CockpitRunSubmission.fromJson);
        _expectRoundTrip(
          CockpitRunAccepted(
            workspaceId: submission.workspaceId,
            runId: 'runA',
            statusUrl: '/api/v2/runs/runA',
            eventsUrl: '/api/v2/runs/runA/events',
            submittedAt: submittedAt,
            replayed: false,
          ),
          CockpitRunAccepted.fromJson,
        );
        _expectRoundTrip(
          CockpitRunCancellationRequest(
            idempotencyKey: CockpitIdempotencyKey('cancel:runA:1'),
            reason: 'CI timeout',
          ),
          CockpitRunCancellationRequest.fromJson,
        );
        _expectRoundTrip(
          CockpitRunCancellation(
            runId: 'runA',
            requestedAt: finishedAt,
            replayed: true,
          ),
          CockpitRunCancellation.fromJson,
        );

        final primary = CockpitApiError(
          code: CockpitErrorCode.driverUnavailable,
          category: CockpitErrorCategory.driver,
          message: 'Driver disconnected.',
          retryable: true,
          responsibleLayer: CockpitResponsibleLayer.driver,
          redactedDetails: const <String, Object?>{'transport': 'stdio'},
        );
        final cleanup = CockpitApiWarning(
          stage: CockpitWarningStage.cleanup,
          error: CockpitApiError(
            code: 'cleanupFailed',
            category: CockpitErrorCategory.resource,
            message: 'Device cleanup failed.',
            retryable: false,
            responsibleLayer: CockpitResponsibleLayer.worker,
          ),
        );
        final evidence = CockpitApiWarning(
          stage: CockpitWarningStage.evidence,
          error: CockpitApiError(
            code: CockpitErrorCode.evidenceFailed,
            category: CockpitErrorCategory.evidence,
            message: 'Final screenshot failed.',
            retryable: true,
            responsibleLayer: CockpitResponsibleLayer.worker,
          ),
        );
        final failure = CockpitFailure(
          primary: primary,
          warnings: <CockpitApiWarning>[cleanup, evidence],
        );
        _expectRoundTrip(
          CockpitApiErrorResponse(
            requestId: 'requestA',
            timestamp: finishedAt,
            failure: failure,
          ),
          CockpitApiErrorResponse.fromJson,
        );

        final invocation = CockpitOperationInvocation(
          kind: 'case.run',
          workspaceId: submission.workspaceId,
          idempotencyKey: CockpitIdempotencyKey('operation:runA:1'),
          input: submission.toJson(),
        );
        _expectRoundTrip(invocation, CockpitOperationInvocation.fromJson);
        expect(
          CockpitOperationCatalog(<CockpitOperationContract<Object?>>[
                _runContract(),
              ])
              .admit(
                invocation,
                negotiatedFeatureIds: _features().map((feature) => feature.id),
              )
              .kind,
          invocation.kind,
        );
        _expectRoundTrip(
          CockpitOperationResult(
            operationId: 'operationA',
            kind: invocation.kind,
            workspaceId: submission.workspaceId,
            lifecycle: CockpitOperationLifecycle.completed,
            outcome: CockpitOperationOutcome.failed,
            submittedAt: submittedAt,
            startedAt: startedAt,
            finishedAt: finishedAt,
            failure: failure,
          ),
          CockpitOperationResult.fromJson,
        );

        final artifact = CockpitArtifactResource(
          artifactId: 'artifactA',
          workspaceId: submission.workspaceId,
          runId: 'runA',
          attemptId: 'attemptA',
          stepExecutionId: 'main/goBack',
          kind: 'evidence.screenshot',
          relativePath: 'artifacts/final.png',
          mediaType: 'image/png',
          sizeBytes: 1024,
          sha256: _hash('b'),
          createdAt: finishedAt,
          downloadUrl: '/api/v2/runs/runA/artifacts/artifactA',
        );
        _expectRoundTrip(artifact, CockpitArtifactResource.fromJson);
        final run = CockpitRunResource(
          projectId: 'projectA',
          workspaceId: submission.workspaceId,
          runId: artifact.runId,
          caseId: testCase.id,
          sourceSha256: _hash('a'),
          lifecycle: CockpitRunLifecycle.completed,
          outcome: CockpitRunOutcome.passed,
          stability: CockpitRunStability.stable,
          submittedAt: submittedAt,
          startedAt: startedAt,
          finishedAt: finishedAt,
          attemptIds: const <String>['attemptA'],
        );
        _expectRoundTrip(run, CockpitRunResource.fromJson);
        _expectRoundTrip(
          CockpitRunCaseResource(
            runId: run.runId,
            caseId: run.caseId,
            sourceSha256: run.sourceSha256,
            attemptIds: run.attemptIds,
            outcome: run.outcome,
            stability: run.stability,
          ),
          CockpitRunCaseResource.fromJson,
        );
        final event = CockpitRunEvent(
          eventId: 'eventA',
          sequence: 1,
          timestamp: finishedAt,
          kind: 'run.completed',
          projectId: run.projectId,
          workspaceId: run.workspaceId,
          runId: run.runId,
          caseId: run.caseId,
          lifecycle: run.lifecycle,
          outcome: run.outcome,
          stability: run.stability,
          targetId: 'deviceA',
          requestedPlane: CockpitTestPlane.semantic,
          actualPlane: CockpitTestPlane.semantic,
          driverId: 'flutterDriver',
          artifacts: <CockpitArtifactReference>[artifact.reference],
        );
        _expectRoundTrip(event, CockpitRunEvent.fromJson);
        CockpitRunEvent.validateSequence(<CockpitRunEvent>[event]);

        _expectRoundTrip(
          CockpitLeaseRequest(
            workspaceId: run.workspaceId,
            resourceKind: CockpitLeaseResourceKind.device,
            resourceId: 'emulator-5554',
            holderId: 'workerA',
            idempotencyKey: CockpitIdempotencyKey('lease:runA:device'),
          ),
          CockpitLeaseRequest.fromJson,
        );
        _expectRoundTrip(
          CockpitLeaseResource(
            leaseId: 'leaseA',
            workspaceId: run.workspaceId,
            resourceKind: CockpitLeaseResourceKind.device,
            resourceId: 'emulator-5554',
            holderId: 'workerA',
            state: CockpitLeaseState.active,
            requestedAt: submittedAt,
            acquiredAt: startedAt,
            expiresAt: finishedAt.add(const Duration(seconds: 30)),
          ),
          CockpitLeaseResource.fromJson,
        );
      },
    );

    test(
      'negotiation, admission, recovery, and state invariants fail closed',
      () {
        final server = CockpitServerInfo(
          instanceId: 'supervisorA',
          apiVersion: CockpitApiVersion(major: 2, minor: 1),
          engineVersion: '2.0.0',
          startedAt: DateTime.utc(2026, 7, 20),
          features: <CockpitFeatureDescriptor>[
            ..._features(),
            CockpitFeatureDescriptor(
              id: 'foundation.minorOne',
              revision: 1,
              minimumApiMinor: 1,
            ),
          ],
        );
        expect(
          () => CockpitProtocolNegotiator.negotiate(
            request: CockpitNegotiationRequest(
              apiVersion: CockpitApiVersion(major: 2, minor: 0),
              requiredFeatures: const <String>['foundation.minorOne'],
            ),
            server: server,
          ),
          throwsA(
            isA<CockpitApiException>().having(
              (error) => error.error.code,
              'code',
              CockpitErrorCode.upgradeRequired,
            ),
          ),
        );
        expect(
          () => CockpitProtocolNegotiator.negotiate(
            request: CockpitNegotiationRequest(
              apiVersion: CockpitApiVersion(major: 3, minor: 0),
            ),
            server: server,
          ),
          throwsA(isA<CockpitApiException>()),
        );

        final futureServer = <String, Object?>{
          ...server.toJson(),
          'futureField': true,
        };
        expect(
          () => CockpitServerInfo.fromJson(futureServer),
          throwsFormatException,
        );
        expect(
          CockpitServerInfo.fromJson(
            futureServer,
            decodePolicy: CockpitDecodePolicy.negotiatedResponse(<String>[
              CockpitFoundationFeature.additiveResponseFields.id,
            ]),
          ).toJson(),
          server.toJson(),
        );

        final futureDescriptor = <String, Object?>{
          ..._runDescriptor().toJson(),
          'safetyEffects': <String>['futureEffect'],
        };
        expect(
          () => CockpitOperationDescriptor.fromJson(futureDescriptor),
          throwsFormatException,
        );
        final decodedFutureDescriptor = CockpitOperationDescriptor.fromJson(
          futureDescriptor,
          decodePolicy: CockpitDecodePolicy.negotiatedResponse(<String>[
            CockpitFoundationFeature.extensibleResponseEnums.id,
          ]),
        );
        expect(
          decodedFutureDescriptor.safetyEffects.single.wireValue,
          'futureEffect',
        );
        expect(decodedFutureDescriptor.safetyEffects.single.isKnown, isFalse);

        final validInvocation = CockpitOperationInvocation(
          kind: 'case.run',
          workspaceId: 'workspaceA',
          idempotencyKey: CockpitIdempotencyKey('operation:1'),
          input: _runSubmission().toJson(),
        );
        final catalog = CockpitOperationCatalog(
          <CockpitOperationContract<Object?>>[_runContract()],
        );
        expect(
          () => catalog.admit(
            CockpitOperationInvocation(
              kind: validInvocation.kind,
              rootId: 'rootA',
              idempotencyKey: validInvocation.idempotencyKey,
              input: validInvocation.input,
            ),
            negotiatedFeatureIds: const <String>[],
          ),
          throwsA(isA<CockpitApiException>()),
        );
        expect(
          () => catalog.admit(
            CockpitOperationInvocation(
              kind: validInvocation.kind,
              workspaceId: 'workspaceA',
              input: validInvocation.input,
            ),
            negotiatedFeatureIds: const <String>[],
          ),
          throwsA(isA<CockpitApiException>()),
        );
        expect(
          () =>
              CockpitOperationCatalog(<CockpitOperationContract<Object?>>[
                _runContract(decodedFutureDescriptor),
              ]).admit(
                validInvocation,
                negotiatedFeatureIds: <String>[
                  CockpitFoundationFeature.extensibleResponseEnums.id,
                ],
              ),
          throwsA(
            isA<CockpitApiException>().having(
              (error) => error.error.code,
              'code',
              CockpitErrorCode.upgradeRequired,
            ),
          ),
        );

        final invalidInputError = isA<CockpitApiException>()
            .having(
              (exception) => exception.error.code,
              'code',
              CockpitErrorCode.invalidRequest,
            )
            .having(
              (exception) => exception.error.category,
              'category',
              CockpitErrorCategory.invalidInput,
            )
            .having(
              (exception) => exception.error.responsibleLayer,
              'responsibleLayer',
              CockpitResponsibleLayer.supervisor,
            )
            .having(
              (exception) => exception.error.redactedDetails,
              'redactedDetails',
              <String, Object?>{
                'kind': 'case.run',
                'requestSchemaRef': r'#/$defs/RunSubmission',
              },
            );
        final missingRequiredInput = <String, Object?>{...validInvocation.input}
          ..remove('workspaceId');
        expect(
          () => catalog.admit(
            CockpitOperationInvocation(
              kind: validInvocation.kind,
              workspaceId: validInvocation.workspaceId,
              idempotencyKey: validInvocation.idempotencyKey,
              input: missingRequiredInput,
            ),
            negotiatedFeatureIds: const <String>[],
          ),
          throwsA(invalidInputError),
        );
        expect(
          () => catalog.admit(
            CockpitOperationInvocation(
              kind: validInvocation.kind,
              workspaceId: validInvocation.workspaceId,
              idempotencyKey: validInvocation.idempotencyKey,
              input: <String, Object?>{
                ...validInvocation.input,
                'unexpected': true,
              },
            ),
            negotiatedFeatureIds: const <String>[],
          ),
          throwsA(invalidInputError),
        );

        final retryableDriverError = CockpitApiError(
          code: CockpitErrorCode.driverUnavailable,
          category: CockpitErrorCategory.driver,
          message: 'Driver unavailable.',
          retryable: true,
          responsibleLayer: CockpitResponsibleLayer.driver,
        );
        expect(
          CockpitRecoveryResolver.resolve(retryableDriverError, <String>[
            CockpitFoundationFeature.cleanRetry.id,
          ]),
          CockpitRecoveryClass.cleanRetry,
        );
        expect(
          CockpitRecoveryResolver.resolve(
            CockpitApiError(
              code: retryableDriverError.code,
              category: CockpitErrorCategory.invalidInput,
              message: retryableDriverError.message,
              retryable: false,
              responsibleLayer: retryableDriverError.responsibleLayer,
            ),
            <String>[CockpitFoundationFeature.cleanRetry.id],
          ),
          CockpitRecoveryClass.cleanRetry,
        );
        final stableRecoveryWithoutFeatures = <String, CockpitRecoveryClass>{
          CockpitErrorCode.invalidRequest: CockpitRecoveryClass.abort,
          CockpitErrorCode.authenticationRequired:
              CockpitRecoveryClass.userAction,
          CockpitErrorCode.authorizationDenied: CockpitRecoveryClass.userAction,
          CockpitErrorCode.notFound: CockpitRecoveryClass.abort,
          CockpitErrorCode.conflict: CockpitRecoveryClass.abort,
          CockpitErrorCode.upgradeRequired: CockpitRecoveryClass.upgrade,
          CockpitErrorCode.unsupportedOperation: CockpitRecoveryClass.abort,
          CockpitErrorCode.resourceBusy: CockpitRecoveryClass.waitAndRetry,
          CockpitErrorCode.staleReference: CockpitRecoveryClass.reconfigure,
          CockpitErrorCode.transportFailed: CockpitRecoveryClass.abort,
          CockpitErrorCode.driverUnavailable: CockpitRecoveryClass.abort,
          CockpitErrorCode.locatorNotFound: CockpitRecoveryClass.abort,
          CockpitErrorCode.assertionFailed: CockpitRecoveryClass.abort,
          CockpitErrorCode.applicationFailed: CockpitRecoveryClass.abort,
          CockpitErrorCode.evidenceFailed: CockpitRecoveryClass.abort,
          CockpitErrorCode.cancelled: CockpitRecoveryClass.abort,
          CockpitErrorCode.interrupted: CockpitRecoveryClass.abort,
          CockpitErrorCode.internalError: CockpitRecoveryClass.abort,
        };
        for (final entry in stableRecoveryWithoutFeatures.entries) {
          expect(
            CockpitRecoveryResolver.resolve(
              CockpitApiError(
                code: entry.key,
                category: CockpitErrorCategory.environment,
                message: 'Recovery classification fixture.',
                retryable: true,
                responsibleLayer: CockpitResponsibleLayer.client,
              ),
              const <String>[],
            ),
            entry.value,
            reason: entry.key,
          );
        }
        expect(
          CockpitRecoveryResolver.resolve(
            CockpitApiError(
              code: CockpitErrorCode.locatorNotFound,
              category: CockpitErrorCategory.internal,
              message: 'Locator was not found.',
              retryable: false,
              responsibleLayer: CockpitResponsibleLayer.application,
            ),
            <String>[CockpitFoundationFeature.locatorRetry.id],
          ),
          CockpitRecoveryClass.retry,
        );
        expect(
          CockpitRecoveryResolver.resolve(
            CockpitApiError(
              code: 'futureError',
              category: CockpitErrorCategory.resource,
              message: 'Unknown future error.',
              retryable: true,
              responsibleLayer: CockpitResponsibleLayer.provider,
            ),
            <String>[
              CockpitFoundationFeature.cleanRetry.id,
              CockpitFoundationFeature.locatorRetry.id,
            ],
          ),
          CockpitRecoveryClass.abort,
        );

        expect(
          () => CockpitOperationResult(
            operationId: 'operationA',
            kind: 'case.run',
            lifecycle: CockpitOperationLifecycle.running,
            submittedAt: DateTime.utc(2026, 7, 20),
          ),
          throwsFormatException,
        );
        expect(
          () => CockpitRunResource(
            projectId: 'projectA',
            workspaceId: 'workspaceA',
            runId: 'runA',
            caseId: 'caseA',
            sourceSha256: _hash('a'),
            lifecycle: CockpitRunLifecycle.completed,
            outcome: CockpitRunOutcome.passed,
            stability: CockpitRunStability.stable,
            submittedAt: DateTime.utc(2026, 7, 20),
            finishedAt: DateTime.utc(2026, 7, 20, 0, 0, 1),
          ),
          throwsFormatException,
        );
        expect(
          () => CockpitArtifactResource(
            artifactId: 'artifactA',
            workspaceId: 'workspaceA',
            runId: 'runA',
            kind: 'evidence.screenshot',
            relativePath: '../outside.png',
            mediaType: 'image/png',
            sizeBytes: 1,
            sha256: _hash('a'),
            createdAt: DateTime.utc(2026, 7, 20),
            downloadUrl: '/api/v2/runs/runA/artifacts/artifactA',
          ),
          throwsFormatException,
        );
        expect(
          () => CockpitServerInfo(
            instanceId: 'supervisorA',
            apiVersion: CockpitApiVersion(major: 2, minor: 0),
            engineVersion: '2.0.0',
            startedAt: DateTime(2026, 7, 20),
          ),
          throwsFormatException,
        );
        expect(
          CockpitRootStateMachine.canTransition(
            CockpitRootState.retired,
            CockpitRootState.active,
          ),
          isFalse,
        );
        expect(
          CockpitWorkspaceStateMachine.canTransition(
            CockpitWorkspaceState.active,
            CockpitWorkspaceState.draining,
          ),
          isTrue,
        );
        expect(
          () => CockpitRunEvent.validateSequence(<CockpitRunEvent>[
            _event(sequence: 1, eventId: 'eventA'),
            _event(sequence: 3, eventId: 'eventB'),
          ]),
          throwsFormatException,
        );
        CockpitRunEvent.validateSequence(<CockpitRunEvent>[
          _event(sequence: 1, eventId: 'eventA'),
          _event(sequence: 3, eventId: 'eventB'),
        ], contiguous: false);
      },
    );
  });
}

List<CockpitFeatureDescriptor> _features() => <CockpitFeatureDescriptor>[
  for (final feature in CockpitFoundationFeature.values)
    CockpitFeatureDescriptor(id: feature.id, revision: 1, minimumApiMinor: 0),
];

CockpitOperationDescriptor _runDescriptor() => CockpitOperationDescriptor(
  kind: 'case.run',
  title: 'Run case',
  description: 'Run one standalone case.',
  scope: CockpitOperationScope.workspace,
  mutationClass: CockpitMutationClass.mutating,
  idempotency: CockpitIdempotencyBehavior.required,
  executionMode: CockpitOperationExecutionMode.job,
  safetyEffects: <CockpitEnumValue<CockpitSafetyEffect>>[
    CockpitEnumValue<CockpitSafetyEffect>.known(CockpitSafetyEffect.capture),
  ],
  requestSchemaRef: r'#/$defs/RunSubmission',
  responseSchemaRef: r'#/$defs/RunAccepted',
);

CockpitOperationContract<CockpitRunSubmission> _runContract([
  CockpitOperationDescriptor? descriptor,
]) => CockpitOperationContract<CockpitRunSubmission>(
  descriptor: descriptor ?? _runDescriptor(),
  inputDecoder: CockpitRunSubmission.fromJson,
);

CockpitRunSubmission _runSubmission() => CockpitRunSubmission(
  workspaceId: 'workspaceA',
  source: CockpitInlineCaseSource(
    testCase: _testCase(),
    sourceSha256: _hash('a'),
  ),
  idempotencyKey: CockpitIdempotencyKey('run:login:1'),
);

CockpitTestCase _testCase() => CockpitTestCase(
  id: 'loginCase',
  target: CockpitTestTargetRequirements(
    platform: 'android',
    targetKind: 'flutterApp',
    plane: CockpitTestPlane.semantic,
  ),
  steps: <CockpitTestStepTemplate>[
    CockpitTestStepTemplate(
      stepId: 'goBack',
      operation: CockpitTestActionOperationTemplate(
        CockpitTestActionTemplate(kind: CockpitTestActionKind.back),
      ),
    ),
  ],
);

CockpitRunEvent _event({required int sequence, required String eventId}) =>
    CockpitRunEvent(
      eventId: eventId,
      sequence: sequence,
      timestamp: DateTime.utc(2026, 7, 20),
      kind: 'run.progress',
      projectId: 'projectA',
      workspaceId: 'workspaceA',
      runId: 'runA',
      caseId: 'caseA',
    );

void _expectRoundTrip<T>(T value, T Function(Object? value) decoder) {
  final json = (value as dynamic).toJson() as Map<String, Object?>;
  expect((decoder(json) as dynamic).toJson(), json);
}

String _hash(String character) => List<String>.filled(64, character).join();
