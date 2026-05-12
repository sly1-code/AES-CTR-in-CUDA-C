# AES-CTR in CUDA C
Final project for CS 4220: a parallel AES-CTR implementation using CUDA C.

## Description
This project implements AES-128-CTR encryption/decryption using CUDA C. It support encrypting and decrypting of text files, then compared the CUDA implementation against a sequential CPU implementation based on 'tiny-AES.c'.

## Features
- AES-128 (CTR Mode) encryption and decryption
- CUDA-based parallel implementation
- CPU baseline comparison using 'tiny-AES.c'
- Benchmarking between CPU and GPU versions
- Generation of random input file of user-defined size for testing

## Repository Structure

```text

├── aes_cuda_ctr.cu        # Main CUDA AES-CTR implementation
├── aes_cuda_ctr.h         # CUDA AES-CTR header
├── aes_block_encrypt.cuh  # CUDA AES block encryption helpers
├── aes_key.c              # AES key expansion code
├── aes_key.h              # AES key expansion header
├── aes.c                  # CPU AES implementation from tiny-AES-c
├── aes.h                  # CPU AES header from tiny-AES-c
└── test_code.cu           # Test / benchmark / demo code
```

## Requirements
- Nvidia GPU with CUDA support
- CUDA Toolkit / nvcc
- C compiler such as gcc
- Linux, WSL, or another CUDA-supported environment

## How to run
Compile:

```bash
nvcc test_code.cu aes_cuda_ctr.cu aes_key.c aes.c -o aes_ctr
```

Run:

```bash
./aes_ctr
```

Note: Within the main CUDA implementation (aes_cuda_ctr.cu) are printf statements for debugging/benchmarking. For cleaner output and better performance, you may wnat to remove or comment these out.

### Usage
The test program allows you to:
- Provide an input file encryption/decryption, or
- Generate a file with random bytes

When prompted, you can enter a desired file size (in bytes), and the the program will generate a random inpute file for testing.

Note: When prompted for input filename, type the full name of file with extension. The same for encryption and decryption, type the full name of what you intend the file extension to be. The test code does not append any file extension.

## Main Code Locations
- Cuda kernel / GPU implementation:
  aes_cuda_ctr.cu, aes_block_encrypt.cuh

- Key expansion logic:
  aes_key.c, aes_key.h
  
- Demo, tests, and benchmarks:
  test_code.cu

- CPU comparison implementation:
  aes.c / aes.h

## Third-Party Code
This project uses tiny-AES-c for the sequential CPU AES implementation. The files aes.c and aes.h are included in this repository for compilation and benchmarking purposes

## Author
Steven Ly
