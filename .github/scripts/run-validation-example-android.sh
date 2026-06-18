#!/usr/bin/env bash
set +e

adb devices
cd "$GITHUB_WORKSPACE/examples/cockpit_demo" || exit 1

dart run cockpit launch-app \
  --project-dir "$GITHUB_WORKSPACE/examples/cockpit_demo" \
  --target cockpit/main.dart \
  --platform android \
  --device-id emulator-5554 \
  --session-port 58491 \
  --launch-timeout-seconds 600 \
  --app-json "$APP_JSON"
LAUNCH_STATUS=$?
if [ "$LAUNCH_STATUS" -ne 0 ]; then
  exit "$LAUNCH_STATUS"
fi

dart run cockpit run-script \
  --app-json "$APP_JSON" \
  --script validation/rapid-smoke.workflow.yaml \
  --platform android \
  --output-root "$BUNDLE_DIR" > "$LOG_PATH" 2>&1
STATUS=$?
cat "$LOG_PATH"
exit "$STATUS"
