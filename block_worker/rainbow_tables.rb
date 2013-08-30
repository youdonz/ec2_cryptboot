require 'socket'
require 'digest/sha1'
require 'base64'

MAXIMUM_PW_LENGTH = 10
MINIMUM_PW_LENGTH = 6
CHAIN_LENGTH=1000000

DECODE_TREE_WITHOUT_FINISH = [[[[[["h", ["f", [["4", "x"], ["j", "q"]]]], [["k", "v"], "b"]], "i"], ["a", ["c", "d"]]], [["r", "n"], ["t", [[["w", ["z", "7"]], "y"], "u"]]]], [[["o", [[[["5", "2"], ["6", "8"]], [["1", "9"], ["0", "3"]]], "g"]], "s"], ["e", [["m", "p"], "l"]]]]
DECODE_TREE_WITH_FINISH = [[[[[[["f", [["0", "9"], ["x", :finish]]], "h"], [["k", "v"], "b"]], "i"], ["a", ["c", "d"]]], [["r", "n"], [[[["w", [["j", "q"], "z"]], "y"], "u"], "t"]]], [[["o", [[[["4", "7"], ["5", "1"]], [["3", "6"], ["8", "2"]]], "g"]], "s"], ["e", [["m", "p"], "l"]]]]

class BitBuffer
  def initialize(data, index)
    @numbers = data.unpack('i*')
    @ary_index = 0
    @taken = 0
    @numbers[0] += index
  end

  def next_bit
    result = (@numbers[@ary_index] >> @taken) & 1
    @taken += 1
    if @taken == 32
      @taken = 0
      @ary_index += 1
    end
    result
  end
end

def hash(password)
  Digest::SHA1.digest(password)
end

def reduce(hash, index)
  # Treat as decompression with Huffman coding to balance letter probabilities
  bits = BitBuffer.new(hash, index)
  pw = ""
  MAXIMUM_PW_LENGTH.times do |i|
    if i < MINIMUM_PW_LENGTH
      ccode = DECODE_TREE_WITHOUT_FINISH
    else
      ccode = DECODE_TREE_WITH_FINISH
    end
    
    while ccode.kind_of?(Array)
      ccode = ccode[bits.next_bit]
    end
    break if ccode == :finish
    pw << ccode
  end
  pw
end

if $0 == __FILE__
  server = ARGV.shift || 'localhost'
  port = (ARGV.shift || 12345).to_i
  
  processor_count = 0
  processor_info = File.read('/proc/cpuinfo')
  processor_info.gsub(/^processor\s+:/) do
    processor_count += 1
  end
  
  STDERR.puts "Starting #{processor_count} workers"
  
  processor_count.times do
    Kernel.fork do
      loop do
        begin
          TCPSocket.open(server, port) do |sock|
            config = sock.gets.chomp
            md = config.match(/^Run '(\d+)' '(\d+)'/)
            if md
              start, stop = md[1].to_i, md[2].to_i
              (start...stop).each do |i|
                start_chain = reduce(hash(i.to_s), -1)
                current = start_chain
                CHAIN_LENGTH.times {|i| digest = hash(current); current = reduce(digest, i)}
                puts "#{start_chain},#{current}"
                sock.puts "#{start_chain},#{current}"
              end
              puts "Done '#{start}' '#{stop}'"
              sock.puts "Done '#{start}' '#{stop}'"
            end
          end
        rescue => e
          # Probably connection issue - wait a bit then try again
          puts e.message
          sleep 10
        end
      end
    end
  end
end

Process.wait

