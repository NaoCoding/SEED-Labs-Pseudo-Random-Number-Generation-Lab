#!/usr/bin/env bash
set -eu

entropy_file=/proc/sys/kernel/random/entropy_avail
if [[ ! -r "$entropy_file" ]]; then
    echo "Cannot read $entropy_file; run this script on Linux." >&2
    exit 1
fi

echo "Press Ctrl-C to stop. Move the mouse, type, and perform disk/network activity."
while :; do
    printf '%s  ' "$(date '+%H:%M:%S')"
    cat "$entropy_file"
    sleep 0.1
done
