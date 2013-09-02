#include "bitstream.h"
#include "huffcode.h"

#include <openssl/sha.h>
#include <stdlib.h>
#include <stdio.h>

// MAX_PW_LENGTH must accommodate the chain number as a decimal
#define MAX_PW_LENGTH 10
#define CHAIN_LENGTH 100000

#define PW_LENGTH_BITS 3
const int pw_lengths[8] = {
  6, 7, 7, 8, 8, 8, 8, 8
};

const int code[] = {
  97, 46, 19, 10, 7, 0, 121, 4, 0, 102, 0, 56, 0, 110, 7, 0, 114, 4, 0, 50, 0, 98, 25, 22, 0, 108, 19, 16, 7, 4, 0, 86, 0, 90, 0, 120, 7, 4, 0, 88, 0, 81, 0, 69, 0, 103, 0, 101, 49, 22, 0, 97, 19, 4, 0, 48, 0, 112, 13, 0, 51, 10, 4, 0, 65, 0, 83, 4, 0, 76, 0, 77, 25, 7, 0, 116, 4, 0, 107, 0, 52, 16, 13, 0, 55, 10, 4, 0, 73, 0, 82, 4, 0, 79, 0, 78, 0, 49, 85, 52, 34, 16, 0, 109, 13, 0, 53, 10, 4, 0, 66, 0, 84, 4, 0, 68, 0, 71, 16, 13, 0, 54, 10, 4, 0, 67, 0, 72, 4, 0, 113, 0, 74, 0, 100, 16, 0, 111, 13, 10, 0, 106, 7, 4, 0, 80, 0, 89, 0, 122, 0, 99, 31, 10, 7, 0, 104, 4, 0, 57, 0, 119, 0, 115, 19, 16, 0, 117, 13, 10, 4, 0, 75, 0, 70, 4, 0, 85, 0, 87, 0, 118, 0, 105
};

void hash(unsigned char* md, const unsigned char* pw, int pwlen) {
  SHA_CTX hash_ctx;
  
  SHA1_Init(&hash_ctx);
  SHA1_Update(&hash_ctx, pw, pwlen);
  SHA1_Final(md, &hash_ctx);
}

int reduce(Huffcode& code, unsigned char* md, unsigned char* pw, int i) {
  // XOR in index - prevent chains merging
  *((int*) md) ^= i;
  
  Bitstream bits((const int*) md, 5);
  
  int j;

  int pw_length_idx = 0;
  for (j = 0; j < PW_LENGTH_BITS; j++) {
    pw_length_idx = (pw_length_idx << 1) + bits.nextBit();
  }
  int pw_length = pw_lengths[pw_length_idx];
  
  for (j = 0; j < pw_length; j++) {
    pw[j] = code.decode(bits);
  }
  return pw_length;
}

int main(int argc, char** argv) {
  Huffcode huff(code);
  
  unsigned char pwbuf[MAX_PW_LENGTH];
  unsigned char md[20];
  
  int start = atoi(argv[1]);
  int stop = atoi(argv[2]);
  
  printf("[%d, %d)\n", start, stop);
  
  int i, j;
  for (i = start; i < stop; ++i) {
    int len = snprintf((char*) pwbuf, MAX_PW_LENGTH, "%d", i);
    
    // Get starting password for this number
    hash(md, pwbuf, len);
    len = reduce(huff, md, pwbuf, -1);
    
    for (j = 0; j < CHAIN_LENGTH; ++j) {
      hash(md, pwbuf, len);
      len = reduce(huff, md, pwbuf, j);
    }
    
    for (j = 0; j < len; j++) {
      putchar(pwbuf[j]);
    }
    printf("\n");
  }
}
