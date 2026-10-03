# NIST Random Number Test Suite Further Lab

This directory contains a reproducible procedure for comparing three random-bit sources with the NIST Statistical Test Suite (STS), based on NIST SP 800-22. It is an experiment guide; it contains no experimental observations or conclusions.

Run the full procedure independently, with the same steps and settings, on:

- Ubuntu 20.04 SEED VM
- Ubuntu 26.04

The sources are standard C `random()`, `/dev/random`, and `/dev/urandom`.

## Test data size

Each input must contain exactly:

```text
1,000,000 bits
= 125,000 bytes
```

Use the same size for all three sources and on both VMs so each STS run compares an equal-length input under the same procedure. The files are raw binary streams, not text containing `0` and `1` characters.

## Step 1 - Install dependencies

On each Ubuntu VM, install the build and archive tools:

```sh
sudo apt update
sudo apt install build-essential unzip wget ca-certificates -y
```

The setup script can use either `wget` or `curl`. Install `curl` if you prefer it and do not have `wget`:

```sh
sudo apt install curl -y
```

### If download reports an untrusted certificate issuer

Do not use an insecure-download option such as `wget --no-check-certificate` or `curl -k`; those disable HTTPS certificate verification. Refresh Ubuntu's trusted certificate bundle and check that the VM clock is correct:

```sh
sudo apt update
sudo apt install --reinstall ca-certificates -y
sudo update-ca-certificates
timedatectl status
```

Then rerun `./scripts/setup_nist_sts.sh`. If the VM is behind a school or company proxy that replaces HTTPS certificates, use the organization's documented trusted CA installation procedure or ask its administrator; do not trust an unknown certificate provided by the connection.

## Step 2 - Setup NIST STS

From this directory, run:

```sh
./scripts/setup_nist_sts.sh
```

The script checks for `gcc`, `make`, `unzip`, and a downloader, then downloads the `sts-2_1_2.zip` archive from the official NIST CSRC site, extracts it under the Git-ignored `tools/` directory, and builds it. It prints the full path to the resulting `assess` executable. Verify it exists and is executable, for example:

```sh
find tools/sts -type f -name assess -print
```

If the archive layout differs, locate the executable with:

```sh
find tools/sts -type f -name assess -print
```

### Manual download fallback

If the automated download URL has changed or the script cannot download the archive:

1. Open the [official NIST SP 800-22 documentation and software page](https://csrc.nist.gov/projects/random-bit-generation/documentation-and-software).
2. Download `sts-2_1_2.zip` from that page.
3. Place it at `further-lab-nist/tools/sts-2_1_2.zip` (create `tools/` if needed).
4. From `further-lab-nist/`, rerun `./scripts/setup_nist_sts.sh`. It will extract and build the local archive. Alternatively, unzip the archive under `tools/sts/` and run `make` in the directory containing its `makefile` (the NIST archive uses a lowercase filename).

The NIST archive names its build file `makefile` in lowercase. The setup script searches case-insensitively for it, including when the archive has an extra top-level directory, then runs `make` in that directory. NIST's SP 800-22 documentation describes the `makefile` as the build input that produces `assess` ([official publication](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-22r1a.pdf)).

The script only downloads from the official NIST host; it does not use third-party mirrors. Downloaded files, source, and binaries stay under ignored `tools/`.

## Step 3 - Generate C `random()` sample

From `further-lab-nist/`, use the helper:

```sh
./scripts/generate_samples.sh c_random
```

It compiles `src/generate_c_random_nist.c` with `gcc -O2 -Wall -Wextra`, writes `data/c_random.bin`, and verifies the size. The standalone equivalent is:

```sh
gcc -O2 -Wall -Wextra -o generate_c_random_nist src/generate_c_random_nist.c
./generate_c_random_nist
wc -c data/c_random.bin
```

The generator uses the fixed seed `srandom(12345)`. A `random()` result provides 31 usable bits. The program packs those bits continuously, most-significant bit first, into bytes and stops after exactly 1,000,000 bits. It does not write a 32-bit integer for each result, which would add a predictable zero high bit. This describes the encoding only; it does not predict a test outcome.

## Step 4 - Generate `/dev/urandom` sample

Run:

```sh
./scripts/generate_samples.sh dev_urandom
```

Equivalent raw command:

```sh
head -c 125000 /dev/urandom > data/dev_urandom.bin
```

The helper checks that the resulting file contains exactly 125,000 bytes.

## Step 5 - Generate `/dev/random` sample

Run:

```sh
./scripts/generate_samples.sh dev_random
```

Equivalent raw command, with elapsed time displayed:

```sh
time head -c 125000 /dev/random > data/dev_random.bin
```

The helper prints a warning before reading. On Ubuntu 20.04, the read may block or take a very long time. Do not bypass this behavior, substitute `/dev/urandom`, or start an entropy-generating daemon. Ctrl-C stops the read; if interrupted, regenerate the sample and verify its size before testing.

To observe the VM while the read is running, open another terminal and run:

```sh
watch -n 0.5 cat /proc/sys/kernel/random/entropy_avail
```

You may also monitor file growth:

```sh
watch -n 1 wc -c /path/to/further-lab-nist/data/dev_random.bin
```

Record the generation time if practical. Do not assume in advance how long the operation will take.

The optional all-samples command runs C and `/dev/urandom` first and `/dev/random` last, with the same warning before the `/dev/random` read:

```sh
./scripts/generate_samples.sh all
```

## Step 6 - Verify all sample sizes

After generating each sample, check all current sample files:

```sh
wc -c data/*.bin
```

Each of `c_random.bin`, `dev_random.bin`, and `dev_urandom.bin` must be exactly `125000` bytes. Do not run STS on an absent or incomplete file. If an interrupted read left a partial file, repeat that source's generation and recheck it.

## Step 7 - Run NIST STS

Run STS separately for each source. Start it from its installation's working directory so its `experiments/AlgorithmTesting/` output is easy to locate. For example, if the executable is under `tools/sts/sts-2.1.2/`:

```sh
cd tools/sts/sts-2.1.2
./assess 1000000
```

Adjust that directory to the path printed by the setup script. When prompted, configure each run for:

- **Input mode:** a user-provided file (not a built-in generator).
- **Input format:** raw binary.
- **Input file:** the absolute path to exactly one of `data/c_random.bin`, `data/dev_random.bin`, or `data/dev_urandom.bin`.
- **Tests:** all available statistical tests.
- **Test parameters:** defaults.
- **Number of bitstreams:** one.
- **Bitstream length:** 1,000,000 bits (already supplied to `assess`).

STS 2.1.2 is an older interactive program. Its exact prompt wording and menu numbers may vary with build or version. Read the prompt text displayed by your installed copy, choose the options whose descriptions match the settings above, and confirm that it identifies file input and binary data before starting. Do not rely on a fixed sequence of keystrokes. If you are unsure which option corresponds to a setting, stop and inspect the installed version's prompts or documentation before proceeding.

Run one invocation per file. For example, provide the full path to `data/c_random.bin`, finish the run, preserve its output as described in Step 8, and repeat with `data/dev_random.bin` and `data/dev_urandom.bin`. Keep the same menu selections and defaults for all three files and on both Ubuntu versions.

## Step 8 - Preserve results immediately

STS commonly writes its output under `experiments/AlgorithmTesting/`. Later runs may replace that output, so copy the complete directory immediately after each run. The `results/` paths below are relative to `further-lab-nist/`; return to that directory before using the copy commands, create the destinations on each VM as needed, and change `STS_DIR` to the actual installation path.

For Ubuntu 20.04, after the C `random()` run:

```sh
STS_DIR="$PWD/tools/sts/sts-2.1.2"  # adjust to the actual STS directory
mkdir -p results/ubuntu20/c_random
cp -a "$STS_DIR/experiments/AlgorithmTesting" results/ubuntu20/c_random/
```

After the other two runs, save to their separate destinations:

```sh
mkdir -p results/ubuntu20/dev_random results/ubuntu20/dev_urandom
cp -a "$STS_DIR/experiments/AlgorithmTesting" results/ubuntu20/dev_random/
# Run STS for dev_urandom, then immediately copy its newly written output:
cp -a "$STS_DIR/experiments/AlgorithmTesting" results/ubuntu20/dev_urandom/
```

On Ubuntu 26.04, use the same procedure with `ubuntu26` destinations:

```sh
mkdir -p results/ubuntu26/c_random results/ubuntu26/dev_random results/ubuntu26/dev_urandom
# Immediately after each corresponding STS run, copy the output directory:
cp -a "$STS_DIR/experiments/AlgorithmTesting" results/ubuntu26/c_random/
cp -a "$STS_DIR/experiments/AlgorithmTesting" results/ubuntu26/dev_random/
cp -a "$STS_DIR/experiments/AlgorithmTesting" results/ubuntu26/dev_urandom/
```

The last block shows the destinations; execute each copy immediately after its corresponding run, before starting the next run. Check the copied files exist. Results are ignored by Git and should be retained locally for the experiment.

## Step 9 - Final verification checklist

Complete all checks independently on each VM.

Ubuntu 20.04:

- [ ] `data/c_random.bin` is 125000 bytes.
- [ ] `data/dev_random.bin` is 125000 bytes.
- [ ] `data/dev_urandom.bin` is 125000 bytes.
- [ ] C `random()` NIST output saved under `results/ubuntu20/c_random/`.
- [ ] `/dev/random` NIST output saved under `results/ubuntu20/dev_random/`.
- [ ] `/dev/urandom` NIST output saved under `results/ubuntu20/dev_urandom/`.
- [ ] Saved `uname -r`, `/etc/os-release`, and `/dev/random` generation time if practical.

Ubuntu 26.04:

- [ ] `data/c_random.bin` is 125000 bytes.
- [ ] `data/dev_random.bin` is 125000 bytes.
- [ ] `data/dev_urandom.bin` is 125000 bytes.
- [ ] C `random()` NIST output saved under `results/ubuntu26/c_random/`.
- [ ] `/dev/random` NIST output saved under `results/ubuntu26/dev_random/`.
- [ ] `/dev/urandom` NIST output saved under `results/ubuntu26/dev_urandom/`.
- [ ] Saved `uname -r`, `/etc/os-release`, and `/dev/random` generation time if practical.

The generated samples, downloaded STS archive and source, binaries, and NIST outputs are local experiment artifacts and are excluded from Git. This repository supplies the procedure only; it contains no claimed PASS/FAIL results or report.
