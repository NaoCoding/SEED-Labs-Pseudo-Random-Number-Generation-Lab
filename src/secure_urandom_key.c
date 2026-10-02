#include <stdio.h>
#include <stdlib.h>

#define KEY_BYTES 32 /* 256 bits */

int main(void)
{
    unsigned char key[KEY_BYTES];
    FILE *random_source = fopen("/dev/urandom", "rb");

    if (random_source == NULL) {
        perror("fopen /dev/urandom");
        return EXIT_FAILURE;
    }
    if (fread(key, 1, sizeof key, random_source) != sizeof key) {
        perror("read /dev/urandom");
        fclose(random_source);
        return EXIT_FAILURE;
    }
    if (fclose(random_source) != 0) {
        perror("fclose /dev/urandom");
        return EXIT_FAILURE;
    }

    printf("256-bit key: ");
    for (size_t i = 0; i < sizeof key; ++i)
        printf("%02x", key[i]);
    putchar('\n');
    return EXIT_SUCCESS;
}
