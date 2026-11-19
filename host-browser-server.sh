#!/bin/sh
set -eu

RUNDIR="/run/user/$(id -u)/cloudflare-warp-browser"

mkdir -p "$RUNDIR"

SOCKET="$RUNDIR/sock"
LOCKFILE="$RUNDIR/lock"
PIDFILE="$RUNDIR/pid"
SOCAT_PID=""

cleanup() {
    if [ -n "$SOCAT_PID" ]; then
        kill -TERM "$SOCAT_PID" 2>/dev/null || true
        wait "$SOCAT_PID" 2>/dev/null || true
    fi
    rm -f "$SOCKET" "$LOCKFILE" "$PIDFILE"
}

forward_signal() {
    signal="$1"
    if [ -n "$SOCAT_PID" ]; then
        kill -"$signal" "$SOCAT_PID" 2>/dev/null || true
        wait "$SOCAT_PID" 2>/dev/null || true
    fi
    case "$signal" in
        HUP) exit 129 ;;
        INT) exit 130 ;;
        TERM) exit 143 ;;
    esac
}

# Ensure unique instance via lock file
exec 9>"$LOCKFILE"
flock -n 9 || { echo "Another instance is running" >&2; exit 0; }

trap cleanup EXIT
trap 'forward_signal HUP' HUP
trap 'forward_signal INT' INT
trap 'forward_signal TERM' TERM

# Write PID for cleanup
echo $$ > "$PIDFILE"

# Clean up old socket
rm -f "$SOCKET"

# Listen on socket using socat
# Fork mode: socat creates a child process for each connection
socat UNIX-LISTEN:"$SOCKET",fork,mode=0666 EXEC:"host-browser-open" &

SOCAT_PID=$!

# Wait for socat to finish
wait "$SOCAT_PID"
