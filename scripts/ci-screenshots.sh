#!/usr/bin/env bash
# Captures and validates a single Android screenshot device class in CI.
set -euo pipefail

: "${SCRUBBY_DEVICE_TYPE:?SCRUBBY_DEVICE_TYPE must be set}"
: "${EMULATOR_PORT:?EMULATOR_PORT must be set}"

screenshot_dir="fastlane/metadata/android/en-US/images/$SCRUBBY_DEVICE_TYPE"
rm -rf "$screenshot_dir"
mkdir -p "$screenshot_dir"

drive_log=$(mktemp)
trap 'rm -f "$drive_log"' EXIT
drive_status=0

# A wedged emulator must not hold the workflow indefinitely. Profile mode is
# intentional: framework assertions can be flaky in integration tests.
timeout --foreground -k 30 1200 flutter drive --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "emulator-$EMULATOR_PORT" >"$drive_log" 2>&1 || drive_status=$?

if [ "$drive_status" -eq 124 ]; then
  echo "flutter drive timed out after 20 minutes; collecting emulator diagnostics" >&2
  adb -s "emulator-$EMULATOR_PORT" logcat -d -t 300 >&2 || true
  adb -s "emulator-$EMULATOR_PORT" shell dumpsys activity top >&2 || true
  adb -s "emulator-$EMULATOR_PORT" shell ps -A >&2 || true
fi

cat "$drive_log"

for number in $(seq 1 5); do
  if [ ! -s "$screenshot_dir/${number}_en-US.png" ]; then
    echo "Missing generated screenshot: ${number}_en-US.png" >&2
    [ "$drive_status" -ne 0 ] && exit "$drive_status"
    exit 1
  fi
done

if [ "$drive_status" -ne 0 ]; then
  if ! grep -q "All tests passed!" "$drive_log"; then
    exit "$drive_status"
  fi
  echo "flutter drive lost the emulator during teardown after all screenshots were generated"
fi
