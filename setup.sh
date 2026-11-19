#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR="$HOME/.local/share/warp-zt"
QUADLET_DIR="$HOME/.config/containers/systemd"
BIN_DIR="$HOME/.local/bin"
APPLICATIONS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
# Port configuration for the container proxy services
# These control the external published ports; internal container ports remain 8080 and 1080.
HTTP_PROXY_PORT="8080"
SOCKS_PROXY_PORT="1080"


run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --http-proxy-port)
            HTTP_PROXY_PORT="$2"
            shift 2
            ;;
        --socks-proxy-port)
            SOCKS_PROXY_PORT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

mkdir -p "$APP_DIR" "$QUADLET_DIR" "$BIN_DIR" "$APPLICATIONS_DIR" "$ICONS_DIR"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' 0
trap 'exit 1' HUP INT TERM
checkmodule -M -m -o "$tmp_dir/container-warp-tun.mod" "$SCRIPT_DIR/container-warp-tun.te"
semodule_package -o "$tmp_dir/container-warp-tun.pp" -m "$tmp_dir/container-warp-tun.mod"
run_as_root semodule -i "$tmp_dir/container-warp-tun.pp"

podman build --network=host -t localhost/warp-zt:latest "$SCRIPT_DIR"

# Replace a container created by the previous manual setup; its data lives in
# the bind mount and named volume, not in the container itself.
if podman container exists warp-zt-proxy; then
    podman rm --force warp-zt-proxy
fi

# Install the quadlet file, then replace the external ports in PublishPort lines
# while keeping internal container ports (1080/8080) as documented in the container.
install -m 0644 "$SCRIPT_DIR/warp-zt-proxy.container" "$QUADLET_DIR/warp-zt-proxy.container"
# Parameterize the external mapped ports in the quadlet.
# Internal container ports remain: privoxy 8080, microsocks 1080
sed -i "s|PublishPort=127.0.0.1:1080:1080|PublishPort=127.0.0.1:${SOCKS_PROXY_PORT}:1080|" "$QUADLET_DIR/warp-zt-proxy.container"
sed -i "s|PublishPort=127.0.0.1:8080:8080|PublishPort=127.0.0.1:${HTTP_PROXY_PORT}:8080|" "$QUADLET_DIR/warp-zt-proxy.container"
install -m 0755 "$SCRIPT_DIR/warp-zt-taskbar.sh" "$BIN_DIR/warp-zt-taskbar"
install -m 0755 "$SCRIPT_DIR/host-browser-server.sh" "$BIN_DIR/host-browser-server"
install -m 0755 "$SCRIPT_DIR/host-browser-open.sh" "$BIN_DIR/host-browser-open"
install -m 0644 "$SCRIPT_DIR/cloudflare-warp-taskbar.desktop" "$APPLICATIONS_DIR/"
install -m 0644 "$SCRIPT_DIR/cloudflare-warp-registration.desktop" "$APPLICATIONS_DIR/"
install -m 0644 "$SCRIPT_DIR/cloudflare-zero-trust-podman.png" "$ICONS_DIR/"

xdg-mime default cloudflare-warp-registration.desktop x-scheme-handler/com.cloudflare.warp
update-desktop-database "$APPLICATIONS_DIR"
gtk-update-icon-cache -f -t "$ICONS_DIR"

systemctl --user daemon-reload
systemctl --user start warp-zt-proxy.service

printf 'Setup complete. Start the GUI with: warp-zt-taskbar\n'
