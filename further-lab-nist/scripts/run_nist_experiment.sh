#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

usage() {
    echo "Usage: $0 {ubuntu20|ubuntu26} [--samples-ready] [--non-interactive] [--resume]" >&2
    echo "  Default: generate three files, each containing 55 streams of 1,000,000 bits." >&2
    echo "  --samples-ready: use existing 55-stream samples after verifying their sizes." >&2
    echo "  --non-interactive: feed the expected NIST STS 2.1.2 menu choices automatically." >&2
    echo "  --resume: skip sources whose AlgorithmTesting output is already saved." >&2
}

if (($# < 1)); then
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
NON_INTERACTIVE=0
RESUME=0
shift
for option in "$@"; do
    case "$option" in
        --samples-ready) SAMPLES_READY=1 ;;
        --non-interactive) NON_INTERACTIVE=1 ;;
        --resume) RESUME=1 ;;
        *)
            echo "ERROR: unknown option: $option" >&2
            usage
            exit 2
            ;;
    esac
done

STREAM_COUNT=55
BITS_PER_STREAM=1000000
SAMPLE_BITS=$((STREAM_COUNT * BITS_PER_STREAM))
SAMPLE_BYTES=$((SAMPLE_BITS / 8))
SOURCES=(c_random dev_random dev_urandom)
# Keep the original one-stream results and save this run in a separate directory.
RESULTS_DIR="$LAB_DIR/results/$VM_TAG/55-streams"

ASSESS="$(find "$LAB_DIR/tools/sts" -type f -name assess -executable -print -quit 2>/dev/null || true)"
if [[ -z "$ASSESS" ]]; then
    echo "ERROR: could not find an executable named assess under $LAB_DIR/tools/sts" >&2
    echo "Run ./scripts/setup_nist_sts.sh first, or install/build NIST STS under tools/sts/." >&2
    exit 1
fi
STS_DIR="$(dirname -- "$ASSESS")"

if ((SAMPLES_READY == 0)); then
    echo "Generating three files with $STREAM_COUNT streams each ($BITS_PER_STREAM bits per stream)."
    echo "The /dev/random read may block; Ctrl-C stops it."
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

done

mkdir -p "$RESULTS_DIR"
{
    echo "VM label: $VM_TAG"
    echo "Collected: $(date --iso-8601=seconds)"
    echo "NIST STS bitstreams per source: $STREAM_COUNT"
    echo "Bits per bitstream: $BITS_PER_STREAM"
    echo "Bytes per source file: $SAMPLE_BYTES"
    echo
    uname -a
    echo
    cat /etc/os-release
} > "$RESULTS_DIR/system-info.txt"

echo
echo "NIST STS executable: $ASSESS"
echo "STS working directory: $STS_DIR"
if ((NON_INTERACTIVE == 1)); then
    echo "Non-interactive mode: feeding the NIST STS 2.1.2 menu sequence for input file, all tests, default parameters, $STREAM_COUNT bitstreams, and binary input."
    echo "Use this only with the official NIST STS 2.1.2 menu flow installed by setup_nist_sts.sh."
else
    echo "For each run, choose user-provided file input, raw binary, all available tests, default parameters, and $STREAM_COUNT bitstreams."
    echo "The script will display the required input path before each interactive run. Confirm the choices shown by your installed STS version."
fi

for source in "${SOURCES[@]}"; do
    sample="$LAB_DIR/data/$source.bin"
    destination="$RESULTS_DIR/$source"

    if [[ -e "$destination/AlgorithmTesting" ]]; then
        if ((RESUME == 1)); then
            echo "Skipping $source; saved output already exists at $destination/AlgorithmTesting"
            continue
        fi
        echo "ERROR: saved output already exists at $destination/AlgorithmTesting" >&2
        echo "Use --resume to keep that result and continue with the remaining sources." >&2
        exit 1
    fi

    mkdir -p "$destination"
    run_log="$destination/assess.log"

    echo
    echo "============================================================"
    echo "Source: $source"
    echo "Input file to select in STS: $sample"
    echo "Output will be saved to: $destination/AlgorithmTesting"
    run_status=0
    if ((NON_INTERACTIVE == 1)); then
        set +e
        printf '0\n%s\n1\n0\n%s\n1\n' "$sample" "$STREAM_COUNT" | (cd "$STS_DIR" && "$ASSESS" "$BITS_PER_STREAM") 2>&1 | tee "$run_log"
        pipeline_status=("${PIPESTATUS[@]}")
        set -e
        run_status="${pipeline_status[1]}"
        tee_status="${pipeline_status[2]}"
    else
        read -r -p "Press Enter when ready to start this interactive STS run (Ctrl-C to stop): " _
        set +e
        (cd "$STS_DIR" && "$ASSESS" "$BITS_PER_STREAM") 2>&1 | tee "$run_log"
        pipeline_status=("${PIPESTATUS[@]}")
        set -e
        run_status="${pipeline_status[0]}"
        tee_status="${pipeline_status[1]}"
    fi

    if ((tee_status != 0)); then
        echo "WARNING: tee could not fully write the console log $run_log" >&2
    fi

    if [[ ! -d "$STS_DIR/experiments/AlgorithmTesting" ]]; then
        echo "ERROR: STS did not create $STS_DIR/experiments/AlgorithmTesting; cannot preserve this run." >&2
        exit 1
    fi

    mkdir -p "$destination"
    cp -a "$STS_DIR/experiments/AlgorithmTesting" "$destination/"
    echo "Saved STS output to $destination/AlgorithmTesting"

    if ((run_status != 0)) && ! grep -Fq "Statistical Testing Complete" "$run_log"; then
        echo "ERROR: STS exited with status $run_status without its completion message. Stopping before the next source." >&2
        exit "$run_status"
    elif ((run_status != 0)); then
        echo "STS printed its completion message and saved its output (exit status $run_status). Continuing."
    fi
done

echo
echo "All three STS runs have returned. Results and VM details are under: $RESULTS_DIR"
