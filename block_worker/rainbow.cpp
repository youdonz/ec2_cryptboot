#include "bitstream.h"
#include "huffcode.h"

#include <openssl/sha.h>
#include <stdlib.h>
#include <stdio.h>

#define PW_LENGTH 8
#define CHAIN_LENGTH 1000000

const int code[] = {
  130, 82, 67, 0, 105, 64, 61, 0, 104, 58, 55, 34, 22, 16, 0, 78, 13, 4, 0, 90, 0, 89, 7, 0, 85, 4, 0, 81, 0, 88, 4, 0, 56, 0, 51, 10, 4, 0, 48, 0, 57, 4, 0, 55, 0, 49, 19, 10, 4, 0, 52, 0, 50, 4, 0, 54, 0, 53, 7, 4, 0, 74, 0, 70, 0, 80, 0, 107, 0, 99, 13, 0, 97, 10, 7, 4, 0, 118, 0, 119, 0, 98, 0, 100, 46, 4, 0, 114, 0, 110, 40, 0, 116, 37, 0, 117, 34, 0, 121, 31, 16, 13, 4, 0, 76, 0, 84, 7, 4, 0, 87, 0, 79, 0, 72, 0, 122, 13, 4, 0, 77, 0, 113, 7, 0, 106, 4, 0, 68, 0, 71, 52, 10, 7, 0, 111, 4, 0, 103, 0, 112, 0, 115, 40, 0, 101, 37, 34, 0, 109, 31, 0, 102, 28, 16, 4, 0, 83, 0, 67, 10, 7, 0, 82, 4, 0, 73, 0, 86, 0, 65, 10, 7, 0, 66, 4, 0, 69, 0, 75, 0, 120, 0, 108
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
  for (j = 0; j < PW_LENGTH; j++) {
    pw[j] = code.decode(bits);
  }
  return j;
}

int main(int argc, char** argv) {
  Huffcode huff(code);
  
  unsigned char pwbuf[PW_LENGTH];
  unsigned char md[20];
  
  int start = atoi(argv[1]);
  int stop = atoi(argv[2]);
  
  printf("[%d, %d)\n", start, stop);
  
  int i, j;
  for (i = start; i < stop; ++i) {
    int len = snprintf((char*) pwbuf, PW_LENGTH, "%d", i);
    
    hash(md, pwbuf, len);
    len = reduce(huff, md, pwbuf, -1);
    
    for (j = 0; j < len; j++) {
      putchar(pwbuf[j]);
    }
    printf(",");
    
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
