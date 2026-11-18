README

# INSTRUCTIONS

## setup

Run the setup script from the project directory:

```
./setup.sh
```

The script builds the proxy image, installs the SELinux policy and desktop
integration, installs the user Quadlet, and starts `warp-zt-proxy.service`.
If a container named `warp-zt-proxy` already exists from the previous setup,
the script replaces it; the WARP data directory and named socket volume remain.
It requires Podman with Quadlet support, systemd user services, and the SELinux
policy tools (`checkmodule`, `semodule_package`, and `semodule`). It uses `sudo`
to install the SELinux policy when not run as root.

## run

Manage the proxy with the user systemd service:

```
systemctl --user start warp-zt-proxy.service
systemctl --user stop warp-zt-proxy.service
```

Launch the GUI separately with:

```
warp-zt-taskbar
```

## troubleshoot

If you need to authenticate for the first time but the GUI is not working:

```
podman exec -it warp-zt-proxy warp-cli --accept-tos registration new <YOUR_TEAM_NAME>
podman exec -it warp-zt-proxy warp-cli --accept-tos registration token "com.cloudflare.warp://<YOUR_TEAM_NAME>://..."
podman exec -it warp-zt-proxy warp-cli --accept-tos connect
```

