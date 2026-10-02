CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -std=c11
BUILD_DIR := build

.PHONY: all clean
all: $(BUILD_DIR)/insecure_time_key $(BUILD_DIR)/brute_force_time_key $(BUILD_DIR)/secure_urandom_key

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/insecure_time_key: src/insecure_time_key.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR)/brute_force_time_key: src/brute_force_time_key.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $< -o $@ -lcrypto

$(BUILD_DIR)/secure_urandom_key: src/secure_urandom_key.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -rf $(BUILD_DIR)
