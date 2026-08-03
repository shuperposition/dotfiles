#!/bin/sh
#
# Start one x11vnc server per screen geometry, each on its own port.
# All are bound to localhost: reach them over an SSH tunnel, e.g.
#   ssh -L 5901:127.0.0.1:5901 user@host
# See x11vnc_setup.md for creating ~/.vnc/passwd.

set -eu

AUTH="$HOME/.vnc/passwd"
XAUTH="/var/run/lightdm/root/:0"
COMMON="-display :0 -auth $XAUTH -forever -bg -repeat -nowf -localhost"

[ -f "$AUTH" ] || {
    echo "missing $AUTH -- create it with: x11vnc -storepasswd" >&2
    exit 1
}

# Native screen
x11vnc -rfbauth "$AUTH" $COMMON -rfbport 5900

# MacBook Pro 15 inch
x11vnc -rfbauth "$AUTH" $COMMON -rfbport 5901 -geometry 2880x1800

# ThinkVision 23 inch
x11vnc -rfbauth "$AUTH" $COMMON -rfbport 5902 -geometry 2560x1440
