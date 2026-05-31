# Rapid Dev Loop

Use this pattern when the goal is fast implementation plus fast runtime verification, not final acceptance delivery on every step.

## Core Rule

Keep each cycle small:

1. make one code change
2. reload only what is needed
3. check one missing fact
4. repeat until behavior is correct
5. run delivery-grade validation only when the feature is ready to claim

## Fastest Useful Loop

1. `launch-app`
2. `read-app --profile minimal`
3. edit code
4. `hot-reload`
5. `run-command` for one action or assertion
6. `read-app --profile minimal` or `inspect-ui --profile inspect` only if the result is still ambiguous
7. `read-errors --max-errors 10`
8. final explicit `captureScreenshot` before claiming visible UI completion

Do not run `launch-app` with shell backgrounding. It returns after readiness
and leaves a supervisor behind for logs, hot reload, hot restart, and
`stop-app`.

Do not call `stop-app` after every loop. Keep the app alive while more edits
are likely; stop only when the user asks, when ending your launched session,
when the app or supervisor is stuck, when hot restart cannot recover, or when
a clean rebuild/relaunch is needed.

For project-specific rapid verifiers, keep the output small and diagnostic:

- completed phases before failure
- failed command id, command type, and command error JSON
- final route or compact state summary after the failed batch
- bounded runtime error previews
- screenshot or recording artifact refs only when they exist

When a feature asserts exact collection counts, isolate app state before launch
or seed a known dataset through the app's production APIs. If a count is larger
than expected, check persistent state cleanup and non-idempotent replay before
changing locators or UI code.

## Target-First Quick Loop

Use this branch when the target is not purely a Flutter app handle:

1. `launch-target`
2. `read-target --profile minimal`
3. one bounded edit or one bounded external action
4. `inspect-surface --profile inspect` only when the target summary is still ambiguous
5. `run-shell` only when the resolved platform truthfully exposes shell control

For desktop Flutter targets, prefer semantic inspection when the remote path is reachable. Fall back to native/window evidence only when that semantic path is unavailable.

## Code-Side Shortcuts

- Use CLI `analyze-files` or MCP `analyze_files` before workspace-wide analysis when the change is local.
- Use `lsp` for hover, definition, signature help, or symbols instead of opening large files blindly.
- Use `grep-package-uris` before `read-package-uris` when you only know the symbol, string, or API fragment inside a dependency.
- Use `pub` for bounded dependency edits.
- Use CLI `pub-dev-search` or MCP `pub_dev_search` before adding a package you do not know well.
- Keep command JSON in files when it grows beyond a few lines.

## Runtime Escalation Rules

- Start with `minimal` when you only need route, app reachability, or a tiny state check.
- Use `standard` when you need a small UI summary after an action.
- `read-app --profile standard` gives counts and `textPreviews`, not a full locator inventory. Escalate to `inspect-ui` only when text, tooltip, semantic IDs, or path clues are still insufficient.
- When a target exposes platform-specific powers, read `capabilities.capabilityProfile` before assuming the older booleans tell the whole story. That is where browser DOM, host shell, and browser-host recording capabilities are surfaced accurately.
- Use `inspect` when a locator is ambiguous, scrolling failed, or the UI changed in an unexpected way.
- Use `read-network` when the missing fact is request traffic, endpoint coverage, or recent network failures.
- For network questions, prefer `run-command` -> `wait-idle` -> `read-network` over a large snapshot read.
- Use `evidence` only for final proof, hard bugs, or artifact-heavy diagnosis.

## Command Strategy

- Prefer one `run-command` per decision point.
- Use `run-batch` only for short deterministic sequences that do not need mid-step reasoning.
- If the next 3-8 mutations are already obvious and order-dependent, prefer `run-batch` to amortize round-trips.
- Key mutating commands already produce best-effort after-action screenshot refs. Add explicit `captureScreenshot` only for final acceptance or a named proof point.
- If motion, transition, or acceptance video is part of the claim, use framework recording before external screen tools. Use bare `start-recording` -> interact/reload -> `stop-recording` for an open-ended development window. Wrap a final deterministic acceptance batch with `run-batch --recording-json` only when explicit acceptance/full options are needed. Verify the returned recording is completed with a non-empty artifact before reporting video proof.
- If a mutating or route-changing step hits `remoteUnavailable`, re-read minimal route or state before retrying.
- If the route already advanced, resume from the smallest remaining step instead of replaying the whole sequence.
- Prefer `read-network` over `inspect-ui` when the uncertainty is purely about HTTP traffic.
- Prefer locator combinations like `text + ancestor.route + type` over long brittle paths.
- Use `key` only when the app already has a meaningful stable key. Do not add keys just to make automation pass.
- Use fuzzy `path` only when semantic signals are insufficient.
- Add `fallbacks` when the same intent can be reached through 2-3 stable signals.
- When identical text appears in multiple visible regions, tighten the locator with `index` or a nearby `ancestor` instead of reaching for code changes.
- `scrollUntilVisible` already probes between internal scroll segments, so try one precise locator before composing manual multi-scroll loops.
- `scrollUntilVisible` can recover once in the opposite direction after it hits the wrong boundary, so only force `reverse` when you already know you started above or below the target region.
- On long pages, first reveal a stable section heading or card, then target deeper controls inside that section.
- If you have already scrolled past the target region, switch direction with `reverse: true` or re-anchor from a stable card instead of repeatedly scrolling forward.
- After selection banners, snackbars, or bottom sheets appear, assume the list shifted and re-anchor before tapping the next off-edge row.
- After a mutation inserts, removes, filters, or reorders collection items, re-anchor from a stable visible signal before the next deep collection gesture.
- Do not parallelize a mutating `run-command` with the follow-up `read-app`, `read-network`, or `inspect-ui` that depends on its side effects.

## Timeout Strategy

- Keep default timeouts unless the step is known to be slow.
- Raise `timeoutMs` for long scrolls, waits, or slow environment transitions.
- Keep `run-shell` on its default bounded timeout for quick probes; raise `--timeout-seconds` only for known-slow host, adb, or simctl commands.
- If a mutating step times out, do not blindly replay the whole batch. Re-read minimal route or state first so you know whether the original action already committed.
- If a deep target keeps slipping under sticky headers or footers, lower `viewportFraction` to `0.35`-`0.55` before escalating to `inspect-ui`.
- After `hot-restart`, re-read route and consider one explicit `wait-idle` or a larger `timeoutMs` for the first deep interaction instead of assuming the session is immediately stable.
- Treat hot reload success as transport-level success, not proof that your literal, layout, or banner copy changed. Re-read the changed control, then relaunch once if the intended delta is still missing.
- Raise command timeout budgets for `pub`, `analyze-files`/`analyze_files`, `run-tests`/`run_tests`, or project creation only when needed.
- If a command times out, inspect whether the environment is blocked before retrying with a larger budget.

## Verification Ladder

- During development: `run-command` -> `read-app`
- Before claiming a fix: `inspect-ui` or `read-errors` if needed
- Before claiming delivery readiness: `run-script`, `run-task`, or `validate-task`

Do not pay delivery-grade cost on every edit. Do pay it before any user-facing completion claim.

## Token-Saving Shell Patterns

- Read one small state slice from the default latest-app handle:
  `flutter_cockpit_devtools read-app --profile minimal --stdout-format json | jq '{currentRouteName,state}'`
- If you stay in one repo, let `launch-app` manage `.dart_tool/flutter_cockpit/latest_app.json` and stop repeating `--app-json` unless another step must reopen a named handle from elsewhere.
- For reload status, project nested fields instead of assuming top-level booleans:
  `flutter_cockpit_devtools hot-reload --stdout-format json | jq '{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded}'`
- For text input flows, verify the next control or saved state instead of expecting `textPreviews` to mirror the field contents:
  `flutter_cockpit_devtools run-command --command-file /tmp/enter_text.json --profile standard`
- Search first, then open one dependency file:
  `flutter_cockpit_devtools grep-package-uris --package flutter --query ThemeData --stdout-format json | jq -r '.packages[0].files[0].packageUri'`
- When only one branch decision matters, extract one field:
  `flutter_cockpit_devtools read-errors --app-json /tmp/flutter_cockpit/app.json --stdout-format json | jq '.hasErrors'`
- Keep larger results off stdout only when a later step needs the full payload again:
  `flutter_cockpit_devtools run-task --config-json /tmp/run_task.json --output /tmp/runTaskResult.json --output-format json`
  `jq '{classification,recommendedNextStep}' /tmp/runTaskResult.json`
- Workspace commands default to the current directory, so omit `--workspace-root` unless you are operating outside the repo you already opened.
- Prefer file inputs over long inline JSON:
  `flutter_cockpit_devtools run-command --command-file /tmp/command.json --profile standard`
- Use `jq` to trim, not to compensate for asking the app for an unnecessarily heavy profile.

## Example

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir <project-dir> \
  --platform <platform> \
  --device-id <device-id>
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools hot-reload
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --profile standard \
  --command-json '{"commandId":"open-filter","commandType":"tap","locator":{"text":"<filter-label>","type":"TextButton","ancestor":{"route":"<current-route>"}}}'
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-app --profile minimal
```

## Expected Agent Behavior

- keep the latest app handle and reuse it instead of relaunching
- in one workspace, prefer the default latest-app handle over repeating `--app-json`
- prefer hot reload over restart when state preservation helps
- use `stop-app` as cleanup or recovery, not as a mandatory iteration step
- ask for one missing fact per cycle
- avoid reading full snapshots unless the smaller profile failed to answer the question
- avoid bundle generation until the feature is ready for a completion claim
