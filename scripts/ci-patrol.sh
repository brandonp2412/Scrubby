#!/usr/bin/env bash

set -u

(
  for _ in $(seq 1 180); do
    if adb shell pm path app.scrubby.scrubby >/dev/null 2>&1; then
      adb shell pm grant \
        app.scrubby.scrubby \
        android.permission.POST_NOTIFICATIONS
      exit 0
    fi
    sleep 2
  done
  exit 1
) &
permission_pid=$!

patrol_status=0
patrol test -t patrol_test/notifications_test.dart || patrol_status=$?
wait "$permission_pid" || true
exit "$patrol_status"
