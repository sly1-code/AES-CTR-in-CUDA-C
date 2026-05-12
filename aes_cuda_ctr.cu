#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <sys/time.h>
#include <cuda_runtime.h>
#include <limits.h>
#include "aes.h"
#include "aes_key.h"

#define AES_BLOCK_SIZE 16
#define AES128_ROUNDKEY_SIZE 176
#define DATA_SIZE (1 << 20)

__constant__ unsigned char d_roundKey[AES128_ROUNDKEY_SIZE];

#include "aes_block_encrypt.cuh"

#define CHECK(call){\
	const cudaError_t cuda_ret = call;\
	if(cuda_ret != cudaSuccess){\
		printf("Error: %s:%d, ", __FILE__, __LINE__);\
		printf("code: %d, reason:%s\n", cuda_ret, cudaGetErrorString(cuda_ret));\
		exit(-1);\
	}\
}

static double myCPUTimer(){
	struct timeval tp;
	gettimeofday(&tp, NULL);
 	return ((double)tp.tv_sec + (double)tp.tv_usec / 1.0e6);
}

__device__ void add_counter_be(unsigned char counter[16], unsigned long long n){
	for(int i = 15; i >= 0 && n > 0; i--){
		unsigned int sum = counter[i] + (unsigned int)(n & 0xffULL);
		counter[i] = (unsigned char)(sum & 0xffU);
		n = (n >> 8) + (unsigned long long)(sum >> 8);
	}
}

__global__ void aes_ctr_kernel(const unsigned char *in, unsigned char *out, size_t len, const unsigned char *base_iv){
	size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
	size_t offset = idx * AES_BLOCK_SIZE;

	if(offset >= len) return;

	unsigned char counter[16];
	unsigned char stream[16];

	#pragma unroll
	for(int i = 0; i < 16; i++){
		counter[i] = base_iv[i];
	}

	add_counter_be(counter, (unsigned long long)idx);
	aes_encrypt_block(counter, stream);

	#pragma unroll
	for(int j = 0; j < 16 && offset + j < len; j++){
		out[offset + j] = in[offset + j] ^ stream[j];
	}
}

extern "C"
void aes128_ctr_d(const unsigned char *h_in, unsigned char *h_out, size_t len, const unsigned char h_iv[16], const unsigned char h_key[16]){
	cudaDeviceSynchronize();

	double startTime_d, endTime_d;

	unsigned char *d_in = NULL;
	unsigned char *d_out = NULL;
	unsigned char *d_iv = NULL;

	size_t num_blocks = (len + AES_BLOCK_SIZE - 1) / AES_BLOCK_SIZE;
	size_t threads_per_block = 256;
	size_t blocks = (num_blocks + threads_per_block - 1) / threads_per_block;

	if (blocks > INT_MAX){
		fprintf(stderr, "Too many CUDA blocks needed: %zu\n", blocks);
		exit(1);
	}

	// allocate device memory
	startTime_d = myCPUTimer();
	CHECK(cudaMalloc((void **)&d_in, len));
	CHECK(cudaMalloc((void **)&d_out, len));
	CHECK(cudaMalloc((void **)&d_iv, 16));
	endTime_d = myCPUTimer();
	printf("\tcudaMalloc:\t\t\t\t\t%f s\n", endTime_d-startTime_d);
	fflush(stdout);

	// copy data to device
	startTime_d = myCPUTimer();
	CHECK(cudaMemcpy(d_in, h_in, len, cudaMemcpyHostToDevice));
	CHECK(cudaMemcpy(d_iv, h_iv, 16, cudaMemcpyHostToDevice));
	endTime_d = myCPUTimer();
	printf("\tcudaMemcpy:\t\t\t\t\t%f s\n", endTime_d - startTime_d);

	unsigned char h_roundKey[AES128_ROUNDKEY_SIZE];
	expand_key_128(h_key, h_roundKey);
	CHECK(cudaMemcpyToSymbol(d_roundKey, h_roundKey, AES128_ROUNDKEY_SIZE));

	// call kernel, aes_ctr_kernel
	startTime_d = myCPUTimer();
	aes_ctr_kernel<<<(int)blocks, (int)threads_per_block>>>(d_in, d_out, len, d_iv);
	CHECK(cudaGetLastError());
	CHECK(cudaDeviceSynchronize());
	endTime_d = myCPUTimer();
	printf("\taes_ctr_kernel<<<%d, %d>>>:\t\t\t%f s\n", (int)blocks, (int)threads_per_block, endTime_d - startTime_d);
	fflush(stdout);

	// copy result to host
	startTime_d = myCPUTimer();
	CHECK(cudaMemcpy(h_out, d_out, len, cudaMemcpyDeviceToHost));
	endTime_d = myCPUTimer();
	printf("\tcudaMemcpy:\t\t\t\t\t%f s\n", endTime_d - startTime_d);
	fflush(stdout);

	CHECK(cudaFree(d_in));
	CHECK(cudaFree(d_out));
	CHECK(cudaFree(d_iv));
}
