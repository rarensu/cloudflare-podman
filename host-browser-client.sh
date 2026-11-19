#!/bin/sh
# Send command line argument to the socket
URL="$1"
if [ -n "$URL" ]; then
    echo "$URL" | socat - UNIX-CONNECT:/run/cloudflare-warp-browser/sock
fi
