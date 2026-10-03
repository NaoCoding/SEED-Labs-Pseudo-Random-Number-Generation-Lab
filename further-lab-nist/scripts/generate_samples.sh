#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$LAB_DIR"

STREAM_COUNT=55
BITS_PER_STREAM=1000000
SAMPLE_BITS=$((STREAM_COUNT * BITS_PER_STREAM))
SAMPLE_BYTES=$((SAMPLE_BITS / 8))
GENERATOR="$LAB_DIR/generate_c_random_nist"

usage() {
    echo "Usage: $0 {c_random|dev_random|dev_urandom|all}" >&2
    echo "Each generated file contains $STREAM_COUNT consecutive $BITS_PER_STREAM-bit streams ($SAMPLE_BITS bits total)." >&2
}

verify_size() {
    local path="$1"
    local size
    size="$(wc -c < "$path")"
    size="${size//[[:space:]]/}"
    if [[ "$size" != "$SAMPLE_BYTES" ]]; then
        echo "ERROR: $path is $size bytes; expected exactly $SAMPLE_BYTES bytes." >&2
        return 1
    fi
    echo "Verified $path: $size bytes"
}

generate_c_random() {
    command -v gcc >/dev/null 2>&1 || {
        echo "ERROR: gcc is required. Install it with: sudo apt install build-essential" >&2
        return 1
    }
    gcc -O2 -Wall -Wextra -o "$GENERATOR" src/generate_c_random_nist.c
    "$GENERATOR"
    verify_size data/c_random.bin
}

generate_dev_urandom() {
    head -c "$SAMPLE_BYTES" /dev/urandom > data/dev_urandom.bin
    verify_size data/dev_urandom.bin
}

generate_dev_random() {
    echo "WARNING: reading $SAMPLE_BYTES bytes from /dev/random may block for a long time, especially on Ubuntu 20.04."
    echo "This command reads /dev/random directly. It does not replace or work around the device. Press Ctrl-C to stop."
    echo "Timing the /dev/random read..."
    time head -c "$SAMPLE_BYTES" /dev/random > data/dev_random.bin
    verify_size data/dev_random.bin
}

mkdir -p data

case "${1:-}" in
    c_random)
        generate_c_random
        ;;
    dev_random)
        generate_dev_random
        ;;
    dev_urandom)
        generate_dev_urandom
        ;;
    all)
        generate_c_random
        generate_dev_urandom
        echo
        generate_dev_random
        ;;
    *)
        usage
        exit 2
        ;;
esac
