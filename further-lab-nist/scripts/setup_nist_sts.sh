#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$LAB_DIR/tools"
ARCHIVE="$TOOLS_DIR/sts-2_1_2.zip"
DOWNLOAD_TMP="$ARCHIVE.part"
EXTRACT_DIR="$TOOLS_DIR/sts"
OFFICIAL_DOWNLOAD="https://csrc.nist.gov/CSRC/media/Projects/Random-Bit-Generation/documents/sts-2_1_2.zip"
OFFICIAL_PAGE="https://csrc.nist.gov/projects/random-bit-generation/documentation-and-software"

missing=()
for command_name in gcc make unzip; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done

DOWNLOADER=""
if command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
elif command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
else
    missing+=("wget or curl")
fi

if ((${#missing[@]} > 0)); then
    printf 'ERROR: missing required command(s): %s\n' "${missing[*]}" >&2
    echo "On Ubuntu, install the usual dependencies with:" >&2
    echo "  sudo apt update && sudo apt install build-essential unzip wget ca-certificates -y" >&2
    echo "Alternatively, install curl instead of wget for downloading." >&2
    exit 1
fi

mkdir -p "$TOOLS_DIR"

if [[ -f "$ARCHIVE" ]] && ! unzip -tq "$ARCHIVE" >/dev/null; then
    echo "Removing an incomplete or invalid archive left by an earlier download attempt: $ARCHIVE" >&2
    rm -f "$ARCHIVE"
fi

if [[ ! -f "$ARCHIVE" ]]; then
    echo "Downloading NIST STS 2.1.2 from the official NIST site..."
    echo "Source page: $OFFICIAL_PAGE"
    if [[ "$DOWNLOADER" == "wget" ]]; then
        if ! wget --https-only -O "$DOWNLOAD_TMP" "$OFFICIAL_DOWNLOAD"; then
            rm -f "$DOWNLOAD_TMP"
            echo "ERROR: download failed. TLS certificate verification was not disabled." >&2
            echo "If the error mentions a certificate issuer, refresh Ubuntu's trusted CA certificates:" >&2
            echo "  sudo apt update && sudo apt install --reinstall ca-certificates -y" >&2
            echo "  sudo update-ca-certificates" >&2
            echo "Also check the VM clock with: timedatectl status" >&2
            echo "Then rerun this script. Do not use wget --no-check-certificate or curl -k." >&2
            exit 1
        fi
    else
        if ! curl --fail --location --proto '=https' --output "$DOWNLOAD_TMP" "$OFFICIAL_DOWNLOAD"; then
            rm -f "$DOWNLOAD_TMP"
            echo "ERROR: download failed. TLS certificate verification was not disabled." >&2
            echo "If the error mentions a certificate issuer, refresh Ubuntu's trusted CA certificates:" >&2
            echo "  sudo apt update && sudo apt install --reinstall ca-certificates -y" >&2
            echo "  sudo update-ca-certificates" >&2
            echo "Also check the VM clock with: timedatectl status" >&2
            echo "Then rerun this script. Do not use wget --no-check-certificate or curl -k." >&2
            exit 1
        fi
    fi
    mv "$DOWNLOAD_TMP" "$ARCHIVE"
else
    echo "Using existing archive: $ARCHIVE"
fi

if ! unzip -tq "$ARCHIVE" >/dev/null; then
    echo "ERROR: $ARCHIVE is not a valid ZIP archive. Remove it and download sts-2_1_2.zip from the official NIST page:" >&2
    echo "  $OFFICIAL_PAGE" >&2
    exit 1
fi

mkdir -p "$EXTRACT_DIR"
unzip -oq "$ARCHIVE" -d "$EXTRACT_DIR"

MAKEFILE="$(find "$EXTRACT_DIR" -type f -name Makefile -print -quit)"
if [[ -z "$MAKEFILE" ]]; then
    echo "ERROR: no Makefile found after extracting the NIST archive into $EXTRACT_DIR" >&2
    exit 1
fi

BUILD_DIR="$(dirname -- "$MAKEFILE")"
echo "Building NIST STS in $BUILD_DIR"
make -C "$BUILD_DIR"

ASSESS="$(find "$EXTRACT_DIR" -type f -name assess -perm -u+x -print -quit)"
if [[ -z "$ASSESS" ]]; then
    echo "ERROR: build completed but no executable named assess was found under $EXTRACT_DIR" >&2
    echo "Inspect the extracted tree and the build output, then follow the manual build notes in README.md." >&2
    exit 1
fi

echo "NIST STS assess executable: $ASSESS"
echo "Run it from its STS working directory so its experiments/ output stays with the installation."
