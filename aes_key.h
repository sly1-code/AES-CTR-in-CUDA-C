#ifndef AES_KEY_H
#define AES_KEY_H

#include <stdint.h>

#define AES128_ROUNDKEY_SIZE 176

#ifdef __cplusplus
extern "C" {
#endif

void expand_key_128(const uint8_t key[16], uint8_t roundKey[AES128_ROUNDKEY_SIZE]);

#ifdef __cplusplus
}
#endif


#endif
