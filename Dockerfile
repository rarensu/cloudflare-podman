FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates iproute2 nftables microsocks privoxy socat xdg-utils \
    && curl -4 -fsSL --retry 3 https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ bookworm main" > /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update && apt-get install -y --no-install-recommends cloudflare-warp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN printf 'listen-address 0.0.0.0:8080\nforward-socks5t / 127.0.0.1:1080 .\n' > /etc/privoxy/warp.conf

EXPOSE 1080
EXPOSE 8080
COPY host-browser-client.sh /usr/local/bin/host-browser
RUN chmod +x /usr/local/bin/host-browser
RUN mkdir -p /run/cloudflare-warp-browser /usr/share/applications /etc/xdg \
    && printf '[Desktop Entry]\nType=Application\nName=Host Browser\nExec=/usr/local/bin/host-browser %%u\nTerminal=false\nNoDisplay=true\nMimeType=x-scheme-handler/http;x-scheme-handler/https;\n' \
        > /usr/share/applications/host-browser.desktop \
    && printf '[Default Applications]\nx-scheme-handler/http=host-browser.desktop\nx-scheme-handler/https=host-browser.desktop\n' \
        > /etc/xdg/mimeapps.list \
    && update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/host-browser 100 \
    && update-alternatives --set x-www-browser /usr/local/bin/host-browser \
    && update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/local/bin/host-browser 100 \
    && update-alternatives --set gnome-www-browser /usr/local/bin/host-browser

ENTRYPOINT ["/entrypoint.sh"]

