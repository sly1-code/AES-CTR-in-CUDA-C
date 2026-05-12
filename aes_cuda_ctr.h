#ifndef AES_CUDA_CTR_H
#define AES_CUDA_CTR_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void aes128_ctr_d(
	const uint8_t *input,
	uint8_t *output,
	size_t len,
	const uint8_t iv[16],
	const uint8_t key[16]
);

#ifdef __cplusplus
}
#endif

#endif
