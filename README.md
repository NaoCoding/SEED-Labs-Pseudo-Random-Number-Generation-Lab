# SEED Labs: Pseudo Random Number Generation

Code and small helper scripts for the [SEED Pseudo Random Number Generation Lab](https://seedsecuritylabs.org/Labs_20.04/Files/Crypto_Random_Number/Crypto_Random_Number.pdf).

The examples follow the lab's tasks. Use them in the SEED Ubuntu 20.04 VM or another Linux environment. The time-seeded generator and brute-force exercise intentionally demonstrate insecure randomness; do not use them to protect real data.

## Build

The C examples require GCC, Make, and OpenSSL development headers/library (the brute-force program links `libcrypto`). On Ubuntu:

```sh
sudo apt update
sudo apt install build-essential libssl-dev
make
```

The generated executables are placed in `build/`.

## Task 1: Time-seeded key

```sh
./build/insecure_time_key
```

Run it twice within one second, then run it again in a later second. Explain how `srand()` initializes `rand()` and why the time-based seed is guessable.

## Task 2: Guess the key

The brute-force program recreates the 16-byte key from each candidate Unix-second seed, then tests it against the known plaintext, ciphertext, and IV from the handout using AES-128-CBC.

The handout gives the candidate period as the two hours before `2018-04-17 23:08:49`. For the UTC interpretation, the inclusive range is `1523999329` through `1524006529`:

```sh
./build/brute_force_time_key 1523999329 1524006529
```

If the timestamp is interpreted in a different timezone, calculate the corresponding Unix-second range and pass that instead. The program must run on a C library whose `rand()` sequence matches the one used to generate the original key; the SEED Ubuntu VM uses glibc. Once the key is found, the lab report should explain the search and use the recovered key as directed by the handout.

## Tasks 3 and 4: Entropy and random devices

```sh
bash scripts/monitor_entropy.sh
bash scripts/sample_random_devices.sh 64
```

Stop the entropy monitor with Ctrl-C. Compare entropy readings while interacting with the system, and observe whether `/dev/random` or `/dev/urandom` reads pause. Linux kernel behavior has changed over time, so record the behavior of the VM you actually use. Avoid piping an unbounded random stream to the terminal.

## Task 5: 256-bit key from `/dev/urandom`

```sh
./build/secure_urandom_key
```

This prints 32 random bytes as 64 hexadecimal characters. Treat the output as a secret and do not include a real production key in a report or commit it to version control.

## Report

The handout requires observations, explanations, code snippets, and screenshots. The scripts and programs are starting points for the coding portions; students should perform the experiments and write up their own findings.
