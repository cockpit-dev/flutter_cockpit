# Runtime Validation Example

Use this pattern when the task requires live app verification instead of code-only reasoning.

If you need exact CLI flags or minimal JSON payload templates while following this flow, read `cli-command-reference.md` first and copy from there instead of guessing.

## Example Flow

1. Decide the task requires `flutter_cockpit` because the app must be run and observed.
2. Choose the lighter loop first:
   - for active edit/reload work, prefer a development session
   - for one-off runtime verification, start or reuse a remote session
3. Verify session reachability before issuing interactive commands.
4. Capture baseline state before moving into a longer workflow.
5. Escalate observation detail only when needed:
   - `quick` or `live` for fast health checks
   - `interactive` or `baseline` for the first structured snapshot
   - `diagnostic` or `investigate` for failures or ambiguity
   - `forensic` only when you need a separate diagnostics artifact

## Example Commands

For iterative development work on a desktop host:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-development-session \
  --project-dir examples/cockpit_demo \
  --target cockpit/main.dart \
  --platform macos \
  --output-json /tmp/flutter_cockpit/development_session.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  collect-development-probe \
  --session-json /tmp/flutter_cockpit/development_session.json \
  --profile interactive
```

Use the same shape for `--platform windows` or `--platform linux`.

On desktop hosts, the normal screenshot and recording path is app-side native media inside `flutter_cockpit`. Do not assume you need shell screenshot or recording tools just to use the standard desktop validation workflow.

For remote runtime verification on a desktop host:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-remote-session \
  --project-dir examples/cockpit_demo \
  --target cockpit/main.dart \
  --platform macos \
  --session-port 48331 \
  --output-json /tmp/flutter_cockpit/session.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  query-remote-session \
  --session-json /tmp/flutter_cockpit/session.json
```

For Android or iOS Simulator, use the same commands but add the platform-specific device flag:

- Android: `--platform android --android-device-id <device>`
- iOS Simulator: `--platform ios --ios-device-id <simulator-udid>`

## Expected Agent Behavior

- prefer `launch-development-session` plus probe/diff during active edit cycles instead of repeatedly relaunching the full app
- do not assume the app is ready until `query-development-session` or `query-remote-session` confirms it
- treat the returned status as baseline evidence and preserve that before-state view for later comparison
- keep high-frequency status reads lightweight; use explicit snapshot or probe collection when richer diagnostics are required
- on desktop hosts, omit mobile device-id flags and rely on the app-side native media path unless the workflow explicitly needs a bounded fallback
- if the session is unreachable, classify the result as `blocked_by_environment`
