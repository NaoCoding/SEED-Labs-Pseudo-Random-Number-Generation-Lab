#define _DEFAULT_SOURCE

#include <stdio.h>
#include <stdlib.h>

enum {
    STREAM_COUNT = 55,
    BITS_PER_STREAM = 1000000,
    SAMPLE_BITS = STREAM_COUNT * BITS_PER_STREAM,
    SAMPLE_BYTES = SAMPLE_BITS / 8,
    RANDOM_BITS = 31
};

int main(void)
{
    FILE *output = fopen("data/c_random.bin", "wb");
    if (output == NULL) {
        perror("cannot open data/c_random.bin");
        return EXIT_FAILURE;
    }

    /* Seed once, then split the continuous output into 55 successive streams. */
    srandom(12345);

    unsigned char byte = 0;
    int bits_in_byte = 0;
    int bits_written = 0;
    int failed = 0;

    while (bits_written < SAMPLE_BITS) {
        const long value = random();

        /* Pack only the 31 useful bits, most-significant bit first. */
        for (int bit = RANDOM_BITS - 1;
             bit >= 0 && bits_written < SAMPLE_BITS;
             --bit) {
            byte = (unsigned char)((byte << 1) | ((value >> bit) & 1L));
            ++bits_in_byte;
            ++bits_written;

            if (bits_in_byte == 8) {
                if (fputc(byte, output) == EOF) {
                    perror("cannot write data/c_random.bin");
                    failed = 1;
                    goto done;
                }
                byte = 0;
                bits_in_byte = 0;
            }
        }
    }

    /* SAMPLE_BITS is byte-aligned, so there must be no partial byte. */
    if (bits_in_byte != 0) {
        fprintf(stderr, "internal error: sample ended with a partial byte\n");
        failed = 1;
    }

done:
    if (fclose(output) != 0) {
        perror("cannot close data/c_random.bin");
        failed = 1;
    }

    if (failed) {
        return EXIT_FAILURE;
    }

    printf("Generated %d streams of %d bits (%d bits, %d bytes) in data/c_random.bin\n",
           STREAM_COUNT, BITS_PER_STREAM, SAMPLE_BITS, SAMPLE_BYTES);
    return EXIT_SUCCESS;
}
