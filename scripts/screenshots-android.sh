#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/screenshot-names.sh"

device="${1:?Usage: screenshots-android.sh <device-id> [device-type] [screenshot]}"
device_type="${2:-phoneScreenshots}"
only="${3:-}"

echo "Running screenshot tests on Android device $device..."

# Clear stale plugin compilation state before each device dimension.
(cd android && ./gradlew clean)

export SCRUBBY_DEVICE_TYPE="$device_type"

dart_define=()
if [ -n "$only" ]; then
    only="$(screenshot_name "$only")"
    dart_define=(--dart-define=SCREENSHOT_ONLY="$only")
    echo "Capturing only: $only"
fi

flutter drive --profile \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshot_test.dart \
    "${dart_define[@]}" \
    -d "$device"

echo "Screenshot tests completed successfully!"
