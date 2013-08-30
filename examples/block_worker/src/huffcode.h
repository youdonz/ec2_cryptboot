#ifndef HUFFCODE_H
#define HUFFCODE_H

#include "bitstream.h"

class Huffcode {
  public:
    Huffcode(const int* base) :
      code_base(base)
    {
    }
    
    int decode(Bitstream& bits)
    {
      int idx = 0;
      
      do {
        int bit = bits.nextBit();
        if (bit) {
          int offs = code_base[idx];
          idx += offs > 0 ? offs + 1 : 2;
        }
      } while (code_base[idx++]);
      return code_base[idx];
    }
  private:
    const int* code_base;
};

#endif
