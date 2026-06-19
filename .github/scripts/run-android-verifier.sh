#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?mode is required}"
PROJECT_DIR="${GITHUB_WORKSPACE:?}/examples/cockpit_demo"
ANDROID_EMULATOR_ID="${ANDROID_EMULATOR_ID:-Pixel_9_Pro}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-600}"
DEVICE_TIMEOUT_SECONDS="${DEVICE_TIMEOUT_SECONDS:-600}"

: "${OUTPUT_ROOT:?OUTPUT_ROOT is required}"
: "${RESULT_JSON:?RESULT_JSON is required}"
: "${LOG_PATH:?LOG_PATH is required}"

mkdir -p "$OUTPUT_ROOT" "$(dirname "$RESULT_JSON")" "$(dirname "$LOG_PATH")"

adb devices
cd "$PROJECT_DIR"

COMMON_ARGS=(
  --project-dir "$PROJECT_DIR"
  --output-root "$OUTPUT_ROOT"
  --output "$RESULT_JSON"
  --output-format json
  --android-emulator-id "$ANDROID_EMULATOR_ID"
  --launch-timeout-seconds "$LAUNCH_TIMEOUT_SECONDS"
)

case "$MODE" in
  rapid-dev)
    COMMAND=(
      dart run tool/verify_rapid_dev.dart
      --platform android
      "${COMMON_ARGS[@]}"
      --device-timeout-seconds "$DEVICE_TIMEOUT_SECONDS"
    )
    ;;
  platform-capabilities)
    COMMAND=(
      dart run tool/verify_platforms.dart
      --platform android
      --exhaustive-system-control
      "${COMMON_ARGS[@]}"
      --device-timeout-seconds "$DEVICE_TIMEOUT_SECONDS"
    )
    ;;
  runtime-loop)
    COMMAND=(
      dart run tool/verify_platforms.dart
      --platform android
      "${COMMON_ARGS[@]}"
    )
    ;;
  *)
    echo "Unsupported Android verifier mode: $MODE" >&2
    exit 64
    ;;
esac

set +e
"${COMMAND[@]}" >"$LOG_PATH" 2>&1
STATUS=$?
set -e

cat "$LOG_PATH" || true
if [ "$STATUS" -ne 0 ]; then
  [ -f "$RESULT_JSON" ] && cat "$RESULT_JSON" || true
fi

exit "$STATUS"
