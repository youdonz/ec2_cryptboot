#ifndef BITSTREAM_H
#define BITSTREAM_H

class Bitstream {
  public:
    Bitstream(const int* source, int count) :
      source(source),
      word_count(0),
      max_words(count),
      bits_current(0)
    {
    }
    int nextBit() {
      int bit = (source[word_count] >> bits_current) & 1;
      bits_current++;
      if (bits_current == 32) {
        bits_current = 0;
        if (word_count < max_words) {
          word_count++;
        } else {
          word_count = 0;
        }
      }
      return bit;
    }
  private:
    const int* source;
    int word_count;
    int max_words;
    int bits_current;
};

#endif
