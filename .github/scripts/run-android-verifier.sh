#!/usr/bin/env bash
set -euo pipefail

MODE="${1:?mode is required}"
PROJECT_DIR="${GITHUB_WORKSPACE:?}/examples/cockpit_demo/cockpit"
ANDROID_EMULATOR_ID="${ANDROID_EMULATOR_ID:-Pixel_9_Pro}"
LAUNCH_TIMEOUT_SECONDS="${LAUNCH_TIMEOUT_SECONDS:-600}"
DEVICE_TIMEOUT_SECONDS="${DEVICE_TIMEOUT_SECONDS:-600}"

: "${OUTPUT_ROOT:?OUTPUT_ROOT is required}"
: "${RESULT_JSON:?RESULT_JSON is required}"
: "${LOG_PATH:?LOG_PATH is required}"

mkdir -p "$OUTPUT_ROOT" "$(dirname "$RESULT_JSON")" "$(dirname "$LOG_PATH")"

adb devices
cd "$PROJECT_DIR"

run_native_conformance() {
  : "${NATIVE_REPORT_JSON:?NATIVE_REPORT_JSON is required for runtime-loop}"
  : "${NATIVE_REPORT_LOG:?NATIVE_REPORT_LOG is required for runtime-loop}"
  local hierarchy="$OUTPUT_ROOT/android_media_projection_hierarchy.xml"
  local device_id
  device_id="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  if [ -z "$device_id" ]; then
    echo "No online Android device was available for native conformance." >&2
    return 1
  fi

  COCKPIT_NATIVE_REPORT_PATH="$NATIVE_REPORT_JSON" \
    flutter drive \
      --driver integration_test/driver.dart \
      --target integration_test/native_plugin_conformance_test.dart \
      -d "$device_id" >"$NATIVE_REPORT_LOG" 2>&1 &
  local drive_pid=$!
  local clicked=0
  local selected_app=0

  for _ in $(seq 1 180); do
    if ! kill -0 "$drive_pid" 2>/dev/null; then
      break
    fi
    adb -s "$device_id" shell uiautomator dump /sdcard/flutter_cockpit_window.xml >/dev/null 2>&1 || true
    adb -s "$device_id" pull /sdcard/flutter_cockpit_window.xml "$hierarchy" >/dev/null 2>&1 || true
    if [ -s "$hierarchy" ]; then
# Android 16 shows a "Choose app to share" picker before the final confirmation.
      action_and_coordinates="$(python3 - "$hierarchy" "$selected_app" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

try:
    root = ET.parse(sys.argv[1]).getroot()
except (OSError, ET.ParseError):
    raise SystemExit(0)

selected_app = sys.argv[2] == "1"
if not selected_app and any(
    node.get("text", "").strip().lower() == "choose app to share"
    for node in root.iter("node")
):
    for node in root.iter("node"):
        if node.get("text", "").strip().lower() != "cockpit_demo":
            continue
        bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
        if bounds:
            x1, y1, x2, y2 = map(int, bounds.groups())
            print(f"app {(x1 + x2) // 2} {(y1 + y2) // 2}")
            raise SystemExit(0)

resource_ids = {
    "android:id/button1",
    "com.android.systemui:id/start",
    "com.android.systemui:id/start_now",
}
labels = re.compile(r"^(start now|start|allow|share)$", re.IGNORECASE)
for node in root.iter("node"):
    if node.get("resource-id") not in resource_ids and not labels.match(node.get("text", "").strip()):
        continue
    bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
    if bounds:
        x1, y1, x2, y2 = map(int, bounds.groups())
        print(f"confirm {(x1 + x2) // 2} {(y1 + y2) // 2}")
        break
PY
)"
      if [ -n "$action_and_coordinates" ]; then
        read -r action x y <<< "$action_and_coordinates"
        adb -s "$device_id" shell input tap "$x" "$y"
        clicked=1
        if [ "$action" = "app" ]; then
          selected_app=1
        fi
      fi
    fi
    sleep 1
  done

  set +e
  wait "$drive_pid"
  local status=$?
  set -e
  cat "$NATIVE_REPORT_LOG" || true
  if [ "$status" -ne 0 ]; then
    echo "Android native conformance failed; last UI hierarchy: $hierarchy" >&2
    [ -f "$hierarchy" ] && cat "$hierarchy" >&2 || true
    return "$status"
  fi
  if [ "$clicked" -eq 0 ]; then
    echo "MediaProjection confirmation was not observed; validating the report branch." >&2
  fi
  python3 "$GITHUB_WORKSPACE/.github/scripts/validate-native-conformance-report.py" \
    "$NATIVE_REPORT_JSON" --platform android
}

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
      --target main.dart
      "${COMMON_ARGS[@]}"
      --device-timeout-seconds "$DEVICE_TIMEOUT_SECONDS"
    )
    ;;
  platform-capabilities)
    COMMAND=(
      dart run tool/verify_platforms.dart
      --platform android
      --target main.dart
      --exhaustive-system-control
      "${COMMON_ARGS[@]}"
      --device-timeout-seconds "$DEVICE_TIMEOUT_SECONDS"
    )
    ;;
  runtime-loop)
    run_native_conformance
    COMMAND=(
      dart run tool/verify_platforms.dart
      --platform android
      --target main.dart
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
