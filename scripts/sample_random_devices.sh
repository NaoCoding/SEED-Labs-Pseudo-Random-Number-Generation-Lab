#!/usr/bin/env bash
set -eu

bytes=${1:-64}
case "$bytes" in
    ''|*[!0-9]*) echo "Usage: $0 [number-of-bytes]" >&2; exit 2 ;;
esac
if (( bytes < 1 )); then
    echo "The number of bytes must be positive." >&2
    exit 2
fi

echo "First $bytes bytes from /dev/random:"
head -c "$bytes" /dev/random | od -An -tx1
echo "First $bytes bytes from /dev/urandom:"
head -c "$bytes" /dev/urandom | od -An -tx1
