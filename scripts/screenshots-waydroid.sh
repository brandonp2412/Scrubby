#!/bin/bash

set -uo pipefail

MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
DRIVE_TIMEOUT="${DRIVE_TIMEOUT:-600}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-120}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_PROP="/var/lib/waydroid/waydroid_base.prop"

device=""
ip=""
show=0
watch=0
headless_pid=""
watchdog_pid=""
watch_args=()
device_type_filter=""
only=""

# Usage: screenshots-waydroid.sh [device-type] [screenshot] [--show|--headed] [--watch]
# device-type: phoneScreenshots | sevenInchScreenshots | tenInchScreenshots | desktop
for arg in "$@"; do
    case "$arg" in
    --show | --headed)
        show=1
        watch_args+=("$arg")
        ;;
    --watch) watch=1 ;;
    *)
        watch_args+=("$arg")
        if [ -z "$device_type_filter" ]; then
            device_type_filter="$arg"
        elif [ -z "$only" ]; then
            only="$arg"
        fi
        ;;
    esac
done

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

add_timestamps() {
    stdbuf -oL tr '\r' '\n' | while IFS= read -r line; do
        printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$line"
    done
}

watch_files() {
    local path
    for path in lib assets integration_test patrol_test test_driver; do
        [ -d "$PROJECT_DIR/$path" ] && find "$PROJECT_DIR/$path" -type f
    done
    [ -f "$PROJECT_DIR/pubspec.yaml" ] && printf '%s\n' "$PROJECT_DIR/pubspec.yaml"
    for path in "$SCRIPT_DIR"/screenshots-*.sh "$SCRIPT_DIR/screenshot-names.sh"; do
        [ -f "$path" ] && printf '%s\n' "$path"
    done
}

run_with_timeout() {
    local secs="$1"
    shift
    timeout --foreground -k 20 "$secs" "$@"
}

start_headless_compositor() {
    [ "$show" -eq 1 ] && return 0

    local before after new_lock i
    before="$(ls /run/user/"$(id -u)"/wayland-*.lock 2>/dev/null || true)"
    WLR_BACKENDS=headless WAYLAND_DISPLAY='' dwl >/tmp/scrubby-headless-dwl.log 2>&1 &
    headless_pid=$!

    for i in $(seq 1 20); do
        after="$(ls /run/user/"$(id -u)"/wayland-*.lock 2>/dev/null || true)"
        new_lock="$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) | head -n1)"
        if [ -n "$new_lock" ]; then
            WAYLAND_DISPLAY="$(basename "$new_lock" .lock)"
            export WAYLAND_DISPLAY
            log "Headless compositor ready on $WAYLAND_DISPLAY (pid $headless_pid)"
            return 0
        fi
        sleep 0.5
    done

    log "ERROR: headless compositor did not create a Wayland socket in time"
    return 1
}

stop_headless_compositor() {
    [ -n "$headless_pid" ] || return 0
    kill -TERM "$headless_pid" >/dev/null 2>&1 || true
    wait "$headless_pid" 2>/dev/null || true
    headless_pid=""
}

unfreeze_watchdog() {
    while true; do
        if timeout 10 waydroid status 2>/dev/null | grep -q 'Container:.*FROZEN'; then
            log '[watchdog] container froze mid-run; unfreezing...'
            sudo waydroid container unfreeze >/dev/null 2>&1 || true
        fi
        sleep 5
    done
}

start_unfreeze_watchdog() {
    unfreeze_watchdog &
    watchdog_pid=$!
}

stop_unfreeze_watchdog() {
    [ -n "$watchdog_pid" ] || return 0
    kill -TERM "$watchdog_pid" >/dev/null 2>&1 || true
    wait "$watchdog_pid" 2>/dev/null || true
    watchdog_pid=""
}

cleanup_hung_adb() {
    [ -n "$device" ] || return 0
    pkill -TERM -f "adb -s ${device} install" 2>/dev/null || true
    sleep 2
    pkill -KILL -f "adb -s ${device} install" 2>/dev/null || true
    adb disconnect "$device" >/dev/null 2>&1 || true
}

pm_ready() {
    local dev="$1" i
    for i in $(seq 1 8); do
        if timeout 20 adb -s "$dev" shell pm path android >/dev/null 2>&1; then
            return 0
        fi
        log "package manager not responding yet (probe $i/8)..."
        sleep 5
    done
    return 1
}

authorize_adb() {
    [ -n "$ip" ] || return 1
    local adbkey_pub="$HOME/.android/adbkey.pub"
    [ -f "$adbkey_pub" ] || return 0

    adb disconnect "$device" >/dev/null 2>&1 || true
    timeout 10 adb start-server >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do
        timeout 10 adb connect "$device" 2>/dev/null | grep -q connected && break
        sleep 2
    done
    adb devices 2>/dev/null | grep -q "$device.*device" && return 0

    log 'Writing adb public key to Waydroid...'
    local key_b64
    key_b64="$(base64 -w0 "$adbkey_pub" 2>/dev/null || base64 "$adbkey_pub" | tr -d '\n')"
    sudo waydroid shell <<<'mkdir -p /data/misc/adb && chmod 755 /data/misc/adb' >/dev/null 2>&1 || return 1
    sudo waydroid shell <<<"echo '${key_b64}' | base64 -d > /data/misc/adb/adb_keys && chmod 644 /data/misc/adb/adb_keys" >/dev/null 2>&1 || true
    sudo waydroid shell <<<'stop adbd 2>/dev/null; start adbd' >/dev/null 2>&1 || true
    sleep 3
    adb disconnect "$device" >/dev/null 2>&1 || true
    timeout 10 adb connect "$device" >/dev/null 2>&1 || true
    sleep 2
}

bring_up_waydroid() {
    local i
    if ! timeout 10 waydroid status 2>/dev/null | grep -q 'Session:.*RUNNING'; then
        log 'Starting Waydroid container...'
        sudo systemctl restart waydroid-container >/dev/null 2>&1 || true
        sleep 10
        log 'Starting Waydroid session...'
        waydroid session start >/dev/null 2>&1 &
        for i in $(seq 1 "$BOOT_TIMEOUT"); do
            timeout 10 waydroid status 2>/dev/null | grep -q 'Session:.*RUNNING' && break
            sleep 1
        done
        if ! timeout 10 waydroid status 2>/dev/null | grep -q 'Session:.*RUNNING'; then
            log "ERROR: Waydroid session did not reach RUNNING within ${BOOT_TIMEOUT}s"
            return 1
        fi
    fi

    if timeout 10 waydroid status 2>/dev/null | grep -q 'Container:.*FROZEN'; then
        log 'Unfreezing Waydroid container...'
        sudo waydroid container unfreeze >/dev/null 2>&1 || true
        sleep 5
    fi
    [ "$show" -eq 1 ] && waydroid show-full-ui >/dev/null 2>&1 &

    log 'Waiting for Waydroid IP address...'
    ip=""
    for _ in $(seq 1 30); do
        ip="$(timeout 10 waydroid status 2>/dev/null | awk -F'\t' '/IP address/ {print $2}')"
        [ -n "$ip" ] && [ "$ip" != UNKNOWN ] && break
        sleep 1
    done
    if [ -z "$ip" ] || [ "$ip" = UNKNOWN ]; then
        log 'ERROR: could not determine Waydroid IP address'
        return 1
    fi
    device="$ip:5555"
    sudo waydroid shell <<<'start adbd' >/dev/null 2>&1 || true
    authorize_adb || log 'WARNING: adb authorization may have failed'
    if ! timeout 90 adb -s "$device" wait-for-device; then
        log "ERROR: device $device did not become ready"
        return 1
    fi
    timeout 10 adb -s "$device" shell settings put secure show_rotation_suggestions 0 >/dev/null 2>&1 || true
    timeout 10 adb -s "$device" shell cmd overlay enable com.android.internal.systemui.navbar.gestural >/dev/null 2>&1 || true
    timeout 10 adb -s "$device" shell settings put system screen_off_timeout 2147483647 >/dev/null 2>&1 || true
    timeout 10 adb -s "$device" shell svc power stayon true >/dev/null 2>&1 || true
}

set_resolution() {
    local w="$1" h="$2"
    log "Setting display resolution to ${w}x${h}..."
    timeout 20 adb -s "$device" shell wm size reset >/dev/null 2>&1 || true
    sleep 1
    if ! timeout 20 adb -s "$device" shell wm size "$w"x"$h" 2>&1 | add_timestamps; then
        log "ERROR: could not set display resolution to ${w}x${h}"
        return 1
    fi
    sleep 2
    local actual
    actual="$(timeout 20 adb -s "$device" shell wm size 2>/dev/null | awk '/Override size/ {print $3}')"
    if [ "$actual" != "${w}x${h}" ]; then
        log "ERROR: display resolution is ${actual:-unknown}, expected ${w}x${h}"
        return 1
    fi
    log "Verified display resolution: $actual"
    timeout 10 adb -s "$device" shell am force-stop app.scrubby.scrubby >/dev/null 2>&1 || true
}

verify_screenshot_sizes() {
    local device_type="$1" w="$2" h="$3" image
    for image in fastlane/metadata/android/en-US/images/"$device_type"/*_en-US.png; do
        [ -e "$image" ] || { log "ERROR: no screenshots were written for $device_type"; return 1; }
        if [ "$(identify -format '%wx%h' "$image")" != "${w}x${h}" ]; then
            log "ERROR: $image has the wrong dimensions"
            return 1
        fi
    done
}

run_device_type() {
    local device_type="$1" w="$2" h="$3" target="$4" attempt rc
    for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
        log "=== [$device_type] attempt ${attempt}/${MAX_ATTEMPTS} (${w}x${h}) ==="
        if [ "$attempt" -eq 1 ] || ! timeout 10 adb -s "$device" shell echo ready >/dev/null 2>&1; then
            bring_up_waydroid || { cleanup_hung_adb; continue; }
        fi
        set_resolution "$w" "$h" || { cleanup_hung_adb; continue; }
        if ! pm_ready "$device"; then
            cleanup_hung_adb
            sudo systemctl restart waydroid-container >/dev/null 2>&1 || true
            sleep 15
            continue
        fi
        start_unfreeze_watchdog
        run_with_timeout "$DRIVE_TIMEOUT" bash -c "cd '$PROJECT_DIR' && '$SCRIPT_DIR/screenshots-android.sh' '$device' '$device_type' '$target'" 2>&1 | add_timestamps
        rc=${PIPESTATUS[0]}
        stop_unfreeze_watchdog
        if [ "$rc" -eq 0 ] && verify_screenshot_sizes "$device_type" "$w" "$h"; then
            return 0
        fi
        log "[$device_type] screenshot run failed (exit $rc); retrying."
        cleanup_hung_adb
    done
    log "[$device_type] ERROR: all ${MAX_ATTEMPTS} attempts failed."
    return 1
}

run_notifications_test() {
    [ "$device_type_filter" = desktop ] && return 0
    command -v patrol >/dev/null 2>&1 || {
        log 'ERROR: notification tests require the Patrol CLI (run: flutter pub global activate patrol_cli)'
        return 1
    }

    log '=== Running Android notification Patrol tests ==='
    (
        cd "$PROJECT_DIR" &&
            run_with_timeout "$DRIVE_TIMEOUT" patrol test \
                --target patrol_test/notifications_test.dart \
                --device "$device"
    ) 2>&1 | add_timestamps
    return "${PIPESTATUS[0]}"
}

main() {
    local device_type width height
    if [ "$watch" -eq 1 ]; then
        command -v entr >/dev/null 2>&1 || { log 'ERROR: --watch requires entr'; exit 1; }
        watch_files | entr -n "$0" "${watch_args[@]}"
        exit $?
    fi
    trap 'stop_unfreeze_watchdog; stop_headless_compositor' EXIT
    start_headless_compositor || exit 1
    cleanup_hung_adb
    waydroid session stop >/dev/null 2>&1 || true
    for _ in $(seq 1 10); do
        timeout 10 waydroid status 2>/dev/null | grep -q 'Session:.*STOPPED' && break
        sleep 1
    done
    sudo sed -i '/^persist\.waydroid\.width=/d;/^persist\.waydroid\.height=/d;/^qemu\.hw\.mainkeys=/d' "$BASE_PROP"
    printf 'qemu.hw.mainkeys=1\n' | sudo tee -a "$BASE_PROP" >/dev/null

    local device_types=(phoneScreenshots sevenInchScreenshots tenInchScreenshots)
    if [ -n "$device_type_filter" ] && [ "$device_type_filter" != desktop ]; then
        case "$device_type_filter" in
        phoneScreenshots | sevenInchScreenshots | tenInchScreenshots) device_types=("$device_type_filter") ;;
        *) log 'ERROR: unknown device type (expected phoneScreenshots, sevenInchScreenshots, tenInchScreenshots, or desktop)'; exit 1 ;;
        esac
    fi
    if [ -z "$device_type_filter" ] || [ "$device_type_filter" != desktop ]; then
        for device_type in "${device_types[@]}"; do
            case "$device_type" in
            phoneScreenshots) width=1080; height=2424 ;;
            sevenInchScreenshots) width=1920; height=1080 ;;
            tenInchScreenshots) width=2560; height=1600 ;;
            esac
            run_device_type "$device_type" "$width" "$height" "$only" || exit 1
        done
        run_notifications_test || exit 1
    fi
    if [ -z "$device_type_filter" ] || [ "$device_type_filter" = desktop ]; then
        local chrome_args=(desktop)
        [ "$show" -eq 1 ] && chrome_args+=(--show)
        [ -n "$only" ] && chrome_args+=("$only")
        cd "$PROJECT_DIR" && "$SCRIPT_DIR/screenshots-chrome.sh" "${chrome_args[@]}" 2>&1 | add_timestamps
        [ "${PIPESTATUS[0]}" -eq 0 ] || exit 1
    fi
    log 'All screenshots generated successfully!'
}

main "$@"
