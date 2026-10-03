#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

usage() {
    echo "Usage: $0 {ubuntu20|ubuntu26} [--samples-ready]" >&2
    echo "  Default: generate all three samples before running NIST STS." >&2
    echo "  --samples-ready: use existing samples after verifying their sizes." >&2
}

if (($# < 1 || $# > 2)); then
    usage
    exit 2
fi

VM_TAG="$1"
case "$VM_TAG" in
    ubuntu20|ubuntu26) ;;
    *)
        echo "ERROR: VM tag must be ubuntu20 or ubuntu26." >&2
        usage
        exit 2
        ;;
esac

SAMPLES_READY=0
if (($# == 2)); then
    if [[ "$2" != "--samples-ready" ]]; then
        usage
        exit 2
    fi
    SAMPLES_READY=1
fi

SAMPLE_BYTES=125000
SOURCES=(c_random dev_random dev_urandom)
RESULTS_DIR="$LAB_DIR/results/$VM_TAG"

ASSESS="$(find "$LAB_DIR/tools/sts" -type f -name assess -executable -print -quit 2>/dev/null || true)"
if [[ -z "$ASSESS" ]]; then
    echo "ERROR: could not find an executable named assess under $LAB_DIR/tools/sts" >&2
    echo "Run ./scripts/setup_nist_sts.sh first, or install/build NIST STS under tools/sts/." >&2
    exit 1
fi
STS_DIR="$(dirname -- "$ASSESS")"

if ((SAMPLES_READY == 0)); then
    echo "Generating the three 1,000,000-bit samples. The /dev/random read may block; Ctrl-C stops it."
    "$SCRIPT_DIR/generate_samples.sh" c_random
    "$SCRIPT_DIR/generate_samples.sh" dev_urandom
    "$SCRIPT_DIR/generate_samples.sh" dev_random
else
    echo "Using existing samples (--samples-ready)."
fi

for source in "${SOURCES[@]}"; do
    sample="$LAB_DIR/data/$source.bin"
    if [[ ! -f "$sample" ]]; then
        echo "ERROR: missing sample: $sample" >&2
        exit 1
    fi
    size="$(wc -c < "$sample")"
    size="${size//[[:space:]]/}"
    if [[ "$size" != "$SAMPLE_BYTES" ]]; then
        echo "ERROR: $sample is $size bytes; expected exactly $SAMPLE_BYTES. Generate it again before running STS." >&2
        exit 1
    fi

    destination="$RESULTS_DIR/$source"
    if [[ -e "$destination/AlgorithmTesting" ]]; then
        echo "ERROR: saved output already exists at $destination/AlgorithmTesting" >&2
        echo "Move or archive that previous result before running this source again; existing results are preserved." >&2
        exit 1
    fi
done

mkdir -p "$RESULTS_DIR"
{
    echo "VM label: $VM_TAG"
    echo "Collected: $(date --iso-8601=seconds)"
    echo
    uname -a
    echo
    cat /etc/os-release
} > "$RESULTS_DIR/system-info.txt"

echo
echo "NIST STS executable: $ASSESS"
echo "STS working directory: $STS_DIR"
echo "For each run, choose user-provided file input, raw binary, all available tests, default parameters, and one bitstream."
echo "The script will display the required input path before each interactive run. Confirm the choices shown by your installed STS version."

for source in "${SOURCES[@]}"; do
    sample="$LAB_DIR/data/$source.bin"
    destination="$RESULTS_DIR/$source"

    echo
    echo "============================================================"
    echo "Source: $source"
    echo "Input file to select in STS: $sample"
    echo "Output will be saved to: $destination/AlgorithmTesting"
    read -r -p "Press Enter when ready to start this interactive STS run (Ctrl-C to stop): " _

    run_status=0
    (cd "$STS_DIR" && "$ASSESS" 1000000) || run_status=$?

    if [[ ! -d "$STS_DIR/experiments/AlgorithmTesting" ]]; then
        echo "ERROR: STS did not create $STS_DIR/experiments/AlgorithmTesting; cannot preserve this run." >&2
        exit 1
    fi

    mkdir -p "$destination"
    cp -a "$STS_DIR/experiments/AlgorithmTesting" "$destination/"
    echo "Saved STS output to $destination/AlgorithmTesting"

    if ((run_status != 0)); then
        echo "ERROR: STS exited with status $run_status after its output was copied. Stopping before the next source." >&2
        exit "$run_status"
    fi
done

echo
echo "All three STS runs have returned. Results and VM details are under: $RESULTS_DIR"
