FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg ca-certificates iproute2 nftables microsocks privoxy \
    && curl -4 -fsSL --retry 3 https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ bookworm main" > /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update && apt-get install -y --no-install-recommends cloudflare-warp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN printf 'listen-address 0.0.0.0:8080\nforward-socks5t / 127.0.0.1:1080 .\n' > /etc/privoxy/warp.conf

EXPOSE 1080
EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]

