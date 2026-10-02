#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define KEY_BYTES 16

int main(void)
{
    unsigned char key[KEY_BYTES];
    time_t seed = time(NULL);

    printf("Seed (Unix seconds): %lld\n", (long long)seed);
#ifndef NO_SRAND
    srand((unsigned int)seed);
#endif

    for (size_t i = 0; i < sizeof key; ++i) {
        key[i] = (unsigned char)(rand() % 256);
        printf("%02x", key[i]);
    }
    putchar('\n');
    return 0;
}
