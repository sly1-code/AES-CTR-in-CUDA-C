#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#include "aes.h"
#include "aes_cuda_ctr.h"

double myCPUTimer(){
	struct timeval tp;
	gettimeofday(&tp, NULL);
 	return ((double)tp.tv_sec + (double)tp.tv_usec / 1.0e6);
}

void random_bytes(unsigned char *buf, size_t len){
	for(size_t i = 0; i < len; i++){
		buf[i] = rand() % 256;
	}
}

static void print_hex(const char *label, const uint8_t *buf, size_t len){
	printf("%s", label);
	for(size_t i = 0; i < len; i++){
		printf("%02x", buf[i]);
	}
	printf("\n");
}

static unsigned char *read_file(const char *filename, size_t *len){
	FILE *fp = fopen(filename, "rb");
	if(!fp){
		perror("Could not open input file");
		return NULL;
	}

	fseek(fp, 0, SEEK_END);
	long size = ftell(fp);
	rewind(fp);

	if(size < 0){
		fclose(fp);
		return NULL;
	}

	unsigned char *buf = (unsigned char *)malloc((size_t)size);
	if(!buf){
		fclose(fp);
		return NULL;
	}

	size_t read_count = fread(buf, 1, (size_t)size, fp);
	fclose(fp);

	if(read_count != (size_t)size){
		free(buf);
		return NULL;
	}

	*len = (size_t)size;
	return buf;
}

static int write_file(const char *filename, const unsigned char *buf, size_t len){
	FILE *fp = fopen(filename, "wb");
	if(!fp){
		perror("Could not open output file");
		return 0;
	}

	size_t written = fwrite(buf, 1, len, fp);
	fclose(fp);
	return written == len;
}

static void strip_newline(char *s){
	s[strcspn(s, "\n")] = '\0';
}

static int get_line(const char *prompt, char *buf, size_t size){
	printf("%s", prompt);
	fflush(stdout);

	if(!fgets(buf, size, stdin)){
		return 0;
	}

	strip_newline(buf);
	return 1;
}

int main(){
	double startTime_h, endTime_h;

	char input_name[256];
	char encrypted_name[256];
	char decrypted_name[256];

	unsigned char key[16];
	unsigned char iv[16];

	srand(42);

	if(!get_line("Input file: ", input_name, sizeof(input_name))) return 1;

	size_t len = 0;
	unsigned char *plaintext = NULL;

	if(strcmp(input_name, "random") == 0){
		char size_str[64];

		if(!get_line("Enter size in bytes: ", size_str, sizeof(size_str))) return 1;

		len = strtoull(size_str, NULL, 10);

		if(len == 0){
			printf("Invalid size.\n");
			return 1;
		}

		plaintext = (unsigned char *)malloc(len);
		if(!plaintext){
			fprintf(stderr, "malloc failed\n");
			return 1;
		}

		random_bytes(plaintext, len);
		write_file("random.txt", plaintext, len);

		printf("Generated %zu random bytes.\n", len);
	} else {
		plaintext = read_file(input_name, &len);
		if(!plaintext){
			printf("Failed to read file.\n");
			return 1;
		}

		printf("Loaded file (%zu bytes).\n", len);
	}

	if(!get_line("Encrypted output file (.bin): ", encrypted_name, sizeof(encrypted_name))) return 1;
	if(!get_line("Decryped output file: ", decrypted_name, sizeof(decrypted_name))) return 1;

	unsigned char *cpu_cipher = (unsigned char *)malloc(len);
	unsigned char *gpu_cipher = (unsigned char *)malloc(len);
	unsigned char *gpu_decrypted = (unsigned char *)malloc(len);

	if(!cpu_cipher || !gpu_cipher || !gpu_decrypted){
		fprintf(stderr, "Host malloc failed\n");
		free(plaintext);
		free(cpu_cipher);
		free(gpu_cipher);
		free(gpu_decrypted);
		return 1;
	}

	size_t print_len = len < 32 ? len : 32;

	random_bytes(key, sizeof(key));
	random_bytes(iv, sizeof(iv));

	memcpy(cpu_cipher, plaintext, len);
	memset(gpu_cipher, 0, len);
	memset(gpu_decrypted, 0, len);

	print_hex("KEY:\t", key, sizeof(key));
	print_hex("IV:\t", iv, sizeof(iv));
	print_hex("PLAINTEXT (first 32 bytes):\t", plaintext, print_len);
	printf("\n");

	struct AES_ctx ctx;
	AES_init_ctx_iv(&ctx, key, iv);

	// calling of tiny aes implementation of ctr (host/cpu version)
	startTime_h = myCPUTimer();
	AES_CTR_xcrypt_buffer(&ctx, cpu_cipher, len);
	endTime_h = myCPUTimer();
	printf("tiny aes-ctr on cpu:\t\t\t%f s\n", endTime_h - startTime_h);
	print_hex("DATA[0:32]: ", cpu_cipher, print_len);
	printf("\n");
	fflush(stdout);

	// calling of cuda implementation of aes-ctr on gpu
	startTime_h = myCPUTimer();
	aes128_ctr_d(plaintext, gpu_cipher, len, iv, key);
	endTime_h = myCPUTimer();
	printf("aes_ctr_d:\t\t\t\t\t\t%f s\n", endTime_h - startTime_h);
	print_hex("DATA[0:32]: ", gpu_cipher, print_len);
	printf("\n");
	fflush(stdout);

	if(memcmp(cpu_cipher, gpu_cipher, len) == 0){
		printf("CPU and GPU ciphertext match.\n\n");
	} else {
		printf("Mismatch between CPU and GPU ciphertext.\n\n");
	}

	write_file(encrypted_name, gpu_cipher, len);

	// calling of cuda implementation of aes-ctr on gpu
	startTime_h = myCPUTimer();
	aes128_ctr_d(gpu_cipher, gpu_decrypted, len, iv, key);
	endTime_h = myCPUTimer();
	printf("aes_ctr_d:\t\t\t\t\t\t%f s\n", endTime_h - startTime_h);
	fflush(stdout);

	if(memcmp(plaintext, gpu_decrypted, len) == 0){
		printf("Decrpyted output matches original.\n\n");
	} else {
		printf("Decrypted output does NOT match original.\n\n");
	}

	write_file(decrypted_name, gpu_decrypted, len);

	free(plaintext);
	free(cpu_cipher);
	free(gpu_cipher);
	free(gpu_decrypted);

	return 0;
}
