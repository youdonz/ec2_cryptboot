require 'socket'
require 'digest/sha1'
require 'base64'

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
            md = config.match(/^Run ('\d+' '\d+')/)
            if md
              IO.popen("./rainbow_gen #{md[1]}", 'r') do |pipe|
                pipe.each_line do |line|
                  sock.print line
                  sock.flush
                end
              end
              if $? == 0
                sock.puts "Done #{md[1]}"
              end
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

