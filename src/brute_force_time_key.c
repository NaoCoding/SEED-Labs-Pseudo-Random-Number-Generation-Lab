#include <openssl/evp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define KEY_BYTES 16

static const unsigned char known_plaintext[KEY_BYTES] = {
    0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x35,
    0x0a, 0x25, 0xd0, 0xd4, 0xc5, 0xd8, 0x0a, 0x34
};
static const unsigned char known_ciphertext[KEY_BYTES] = {
    0xd0, 0x6b, 0xf9, 0xd0, 0xda, 0xb8, 0xe8, 0xef,
    0x88, 0x06, 0x60, 0xd2, 0xaf, 0x65, 0xaa, 0x82
};
static const unsigned char iv[KEY_BYTES] = {
    0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02,
    0x01, 0x00, 0xa2, 0xb2, 0xc2, 0xd2, 0xe2, 0xf2
};

static int decrypts_known_block(const unsigned char key[KEY_BYTES])
{
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    unsigned char plaintext[KEY_BYTES + EVP_MAX_BLOCK_LENGTH];
    int first_len = 0;
    int final_len = 0;
    int matches = 0;

    if (ctx == NULL)
        return 0;

    if (EVP_DecryptInit_ex(ctx, EVP_aes_128_cbc(), NULL, key, iv) == 1 &&
        EVP_CIPHER_CTX_set_padding(ctx, 0) == 1 &&
        EVP_DecryptUpdate(ctx, plaintext, &first_len, known_ciphertext,
                          sizeof known_ciphertext) == 1 &&
        EVP_DecryptFinal_ex(ctx, plaintext + first_len, &final_len) == 1 &&
        first_len + final_len == KEY_BYTES &&
        memcmp(plaintext, known_plaintext, KEY_BYTES) == 0) {
        matches = 1;
    }

    EVP_CIPHER_CTX_free(ctx);
    return matches;
}

int main(int argc, char **argv)
{
    unsigned long long start, end;
    unsigned long long seed;

    if (argc != 3) {
        fprintf(stderr, "Usage: %s <first Unix timestamp> <last Unix timestamp>\n",
                argv[0]);
        return EXIT_FAILURE;
    }

    start = strtoull(argv[1], NULL, 10);
    end = strtoull(argv[2], NULL, 10);
    if (start > end || end > 0xffffffffULL) {
        fprintf(stderr, "Invalid timestamp range (expected 0 <= start <= end <= 2^32-1).\n");
        return EXIT_FAILURE;
    }

    for (seed = start; seed <= end; ++seed) {
        unsigned char key[KEY_BYTES];

        /* This must match the C library's rand() implementation used to make
         * Alice's key. The SEED Ubuntu VM uses glibc. */
        srand((unsigned int)seed);
        for (size_t i = 0; i < sizeof key; ++i)
            key[i] = (unsigned char)(rand() % 256);

        if (decrypts_known_block(key)) {
            printf("Matching seed: %llu\nKey: ", seed);
            for (size_t i = 0; i < sizeof key; ++i)
                printf("%02x", key[i]);
            putchar('\n');
            return EXIT_SUCCESS;
        }
    }

    puts("No matching seed found in this range.");
    return EXIT_FAILURE;
}
