#!/bin/bash
set -e

cleanup() {
    sig="$1"
    if [ -n "$CHILD_PIDS" ]; then
        kill -s "$sig" $CHILD_PIDS 2>/dev/null || true
    fi
    wait
    trap - "$sig"
    kill -s "$sig" "$$"
}

trap 'cleanup TERM' TERM
trap 'cleanup INT' INT

if [ "${1:-}" = "warp-taskbar" ]; then
    # GUI Mode: launch warp-taskbar with signal trapping
    trap 'cleanup TERM' INT
    warp-taskbar &
    CHILD_PIDS=$!
    wait
elif [ "${1:-}" = "warp-svc" ]; then
    # Start the WARP daemon in the background
    warp-svc &
    WARP_PID=$!
    CHILD_PIDS="$WARP_PID"

    # Wait for warp-svc socket to become ready
    until warp-cli --accept-tos status >/dev/null 2>&1; do
        sleep 1
    done

    # Connect if already registered to your Zero Trust organization
    if [ -f /var/lib/cloudflare-warp/reg.json ]; then
        warp-cli --accept-tos connect || true
    fi

    # Start HTTP proxy on all container interfaces (port 8080)
    privoxy --no-daemon /etc/privoxy/warp.conf &
    PRIVOXY_PID=$!
    CHILD_PIDS="$CHILD_PIDS $PRIVOXY_PID"

    # Start SOCKS5 proxy on all container interfaces (port 1080)
    exec microsocks -i 0.0.0.0 -p 1080 &
    SOCKS_PID=$!
    CHILD_PIDS="$CHILD_PIDS $SOCKS_PID"

    wait
else
    echo "Usage: $0 {warp-taskbar|warp-svc}"
    exit 1
fi
