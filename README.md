# SEED Labs: Pseudo Random Number Generation

Code and helper scripts for the [SEED Pseudo Random Number Generation Lab](https://seedsecuritylabs.org/Labs_20.04/Files/Crypto_Random_Number/Crypto_Random_Number.pdf). The examples are intended for the SEED Ubuntu 20.04 VM and Ubuntu 26.04. The time-seeded generator and brute-force exercise demonstrate insecure randomness; do not use them to protect real data.

## Setup / Build

Install the compiler, Make, and OpenSSL development files (needed by the Task 2 program):

```sh
sudo apt update
sudo apt install build-essential libssl-dev
make
```

`make` builds all examples under `build/`. Run `make clean && make` to rebuild from a clean state.

## Task 1 – Time-seeded PRNG

Run both builds from the same source file:

```sh
./build/insecure_time_key
./build/insecure_time_key_no_srand
```

Run each program multiple times. With `srand(time(NULL))`, different Unix-second seeds generate different pseudo-random sequences; executions within the same second can repeat the sequence. Without `srand()`, separate executions start from the C library implementation's default PRNG state/seed and therefore produce the same `rand()` sequence. Exact values depend on the C library, so no key value is expected in advance. Both programs print the time seed for comparison, but the no-`srand()` build does not use it to seed `rand()`.

## Task 2 – Guessing the key

The program tries candidate Unix-second seeds, reproduces the 16-byte key with `rand()`, and checks the result against the known plaintext, ciphertext, and IV from the handout using AES-128-CBC. Convert the handout timestamp using the intended timezone explicitly so the result does not depend on the VM's configured timezone:

```sh
TZ=America/New_York date -d "2018-04-17 23:08:49" +%s
# 1524020929
./build/brute_force_time_key 1524013729 1524020929
```

The candidate interval is the inclusive two hours before that timestamp. Unix timestamps identify absolute moments, but converting the handout's human-readable local time into one depends on the timezone used for interpretation. The brute-force program must use a C library whose `rand()` sequence matches the generator; the SEED Ubuntu VM uses glibc.

## Task 3 – Kernel entropy

Run the handout's entropy observation command:

```sh
watch -n .1 cat /proc/sys/kernel/random/entropy_avail
```

Observe and record the readings while idle, moving and clicking the mouse, typing, performing disk/file activity, and using the network/browser. Do not assume in advance which activity will change the displayed value; report what you observe on each VM. The timestamped helper is an alternative way to monitor the same value:

```sh
bash scripts/monitor_entropy.sh
```

Stop either monitor with Ctrl-C.

## Task 4 – /dev/random

Use two terminals, as in the handout.

Terminal A:

```sh
cat /dev/random | hexdump
```

Terminal B:

```sh
watch -n .1 cat /proc/sys/kernel/random/entropy_avail
```

Observe what happens while idle and while interacting with the VM, then record the output and entropy readings. `/dev/random` behavior has changed across Linux kernel versions, so report what happens on Ubuntu 20.04 and Ubuntu 26.04 rather than trying to match older documentation. The bounded helper below only samples a short amount from each device; it does not replace this continuous observation experiment:

```sh
bash scripts/sample_random_devices.sh 64
```

Stop the continuous reader with Ctrl-C.

## Task 5 – /dev/urandom and 256-bit key

First observe a stream from `/dev/urandom`:

```sh
cat /dev/urandom | hexdump
```

Stop it with Ctrl-C. Then generate and analyze a 1 MiB sample. Install `ent` if it is not already available:

```sh
sudo apt install ent
head -c 1M /dev/urandom > output.bin
ent output.bin
```

`output.bin` is ignored by Git. Finally, generate the lab's 256-bit key:

```sh
./build/secure_urandom_key
```

The program reads 32 bytes (32 × 8 = 256 bits); hexadecimal output contains 64 hex characters. Treat key output as secret and do not commit real keys.

## Suggested Ubuntu 20.04 vs Ubuntu 26.04 comparison workflow

Run the same commit and source code on both VMs and record separate results. Record the environment on each VM before comparing:

```sh
cat /etc/os-release
uname -r
uname -m
date
timedatectl
openssl version
```

For both VMs, capture or record the same evidence:

- Task 1 with `srand()` and without `srand()`
- Task 2 recovered seed and key
- Task 3 entropy observations
- Task 4 `/dev/random` behavior
- Task 5 `/dev/urandom` and `ent` results
- Task 5 generated 256-bit key (redact it if the output should remain secret)

Kernel and library versions may help explain differences. Do not assume the results are identical across systems.

## Report / evidence

The handout asks for observations, explanations, code snippets, and screenshots. Include your own results from both systems where applicable, explain surprising behavior, and do not present unobserved outcomes as facts.
