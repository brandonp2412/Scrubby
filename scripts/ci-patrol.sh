#!/usr/bin/env bash

set -u

(
  while true; do
    if adb shell pm path app.scrubby.scrubby >/dev/null 2>&1; then
      adb shell pm grant \
        app.scrubby.scrubby \
        android.permission.POST_NOTIFICATIONS || true
      adb shell appops set \
        app.scrubby.scrubby \
        POST_NOTIFICATION \
        allow || true
    fi
    sleep 1
  done
) &
permission_pid=$!

patrol_status=0
patrol test -t patrol_test/notifications_test.dart || patrol_status=$?
kill "$permission_pid" 2>/dev/null || true
wait "$permission_pid" 2>/dev/null || true
exit "$patrol_status"
