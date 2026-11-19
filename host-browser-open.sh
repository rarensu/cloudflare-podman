#!/bin/sh
# Read URL from stdin (sent via socket by the client)
read URL
# Open the URL using xdg-open
if [ -n "$URL" ]; then
    xdg-open "$URL"
fi
