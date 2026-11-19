#!/bin/sh
set -eu

# Start host-browser server if not already running
if [ -z "$(pgrep -f "host-browser-server")" ]; then
    $HOME/.local/bin/host-browser-server &
    HOST_BROWSER_PID=$!
    # Trap EXIT to kill the server when this script exits
    trap "kill $HOST_BROWSER_PID 2>/dev/null" EXIT
fi

if [ "$(podman inspect -f '{{.State.Running}}' warp-zt-gui 2>/dev/null)" = "true" ]; then
    # If the container is already running, use it (brings the existing window to the foreground)
    podman exec -d warp-zt-gui /entrypoint.sh warp-taskbar
else
    if ! systemctl --user is-active --quiet warp-zt-proxy.service; then
        systemctl --user start warp-zt-proxy.service
    fi
    systemctl --user is-active warp-zt-proxy.service >/dev/null

    # Clean up any stopped/exited container remnants from a previous crashed session
    podman rm warp-zt-gui 2>/dev/null || true

    # Spin up a fresh ephemeral container with the shared socket and BROWSER variable
    podman run --rm -d \
      --name warp-zt-gui \
      --pid=container:warp-zt-proxy \
      --security-opt label=disable \
      -v warp-sock:/run/cloudflare-warp \
      -v "$HOME/.local/share/warp-zt:/var/lib/cloudflare-warp:ro" \
      -v /run/user/$(id -u)/cloudflare-warp-browser:/run/cloudflare-warp-browser \
      -e DISPLAY="$DISPLAY" \
      -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
      -e XDG_RUNTIME_DIR="/run/user/$(id -u)" \
      -e DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
      -e BROWSER=host-browser \
      -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
      -v "/run/user/$(id -u)/bus:/run/user/$(id -u)/bus" \
      ${WAYLAND_DISPLAY:+-v "/run/user/$(id -u)/$WAYLAND_DISPLAY:/run/user/$(id -u)/$WAYLAND_DISPLAY"} \
      warp-zt warp-taskbar
fi

if [ -n "${HOST_BROWSER_PID:-}" ]; then
    podman wait warp-zt-gui
fi

