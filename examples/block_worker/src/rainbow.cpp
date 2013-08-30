#include "bitstream.h"
#include "huffcode.h"

#include <openssl/sha.h>
#include <stdlib.h>
#include <stdio.h>

#define PW_LENGTH 8
#define CHAIN_LENGTH 100000

const int code[] = {
  130, 115, 82, 79, 49, 46, 0, 102, 43, 16, 10, 0, 67, 7, 0, 82, 4, 0, 73, 0, 86, 4, 0, 65, 0, 66, 25, 22, 4, 0, 69, 0, 75, 16, 0, 78, 13, 4, 0, 90, 0, 89, 7, 0, 85, 4, 0, 81, 0, 88, 0, 120, 0, 104, 28, 22, 10, 4, 0, 49, 0, 48, 4, 0, 54, 0, 52, 10, 4, 0, 51, 0, 50, 4, 0, 57, 0, 56, 4, 0, 107, 0, 118, 0, 105, 31, 0, 97, 28, 0, 99, 25, 22, 19, 4, 0, 55, 0, 53, 13, 7, 4, 0, 74, 0, 70, 0, 80, 4, 0, 76, 0, 84, 0, 119, 0, 98, 13, 4, 0, 114, 0, 110, 7, 4, 0, 100, 0, 117, 0, 116, 52, 40, 37, 0, 111, 34, 31, 0, 121, 28, 13, 0, 122, 10, 7, 4, 0, 87, 0, 79, 0, 72, 0, 77, 13, 4, 0, 113, 0, 106, 7, 4, 0, 68, 0, 71, 0, 83, 0, 103, 0, 115, 10, 0, 101, 7, 4, 0, 112, 0, 109, 0, 108
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
