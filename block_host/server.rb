require 'eventmachine'
require 'optparse'

class SeedBatchServer < EM::Connection
  def initialize(config, counters, callback = nil)
    @config = config
    @counters = counters
    @callback = callback
  end

  def post_init
    @my_start, @my_end = @counters[:repeat_queue].pop
    unless @my_end
      @my_start, @my_end = next_interval
    end
    if @my_start >= @config[:stop_index]
      send_data "Done\n"
      disconnect
    else
      @logfile = "#{@config[:directory]}/#{@my_start}.block"
      @log = File.open(@logfile, 'w')
      send_data "Run '#{@my_start}' '#{@my_end}'\n"
    end
  end

  def receive_data(data)
    if @log
      @log.write data
    end
  end

  def unbind
    if @log
      @log.close
      @log = nil
      
      readback = File.read(@logfile)
      if readback.match(/^Done '#{@my_start}' '#{@my_end}'\r?\n?\z/)
        STDERR.puts "Success on block #{@my_start} -> #{@my_end}"
        @callback.call(@my_start, @my_end, readback) if @callback
      else
        STDERR.puts "Incomplete block #{@my_start} -> #{@my_end}"
        File.unlink(@logfile)
        @counters[:repeat_queue] << [@my_start, @my_end]
      end
    end
  end

  private

  def next_interval
    block = @counters[:next_block]
    @counters[:next_block] += 1
    start_index = block * @config[:block_size] + @config[:start_index]
    end_index = start_index + @config[:block_size]
    [start_index, end_index]
  end
end

options = {}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: server.rb [options]"

  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
  end
  
  options[:host] = '0.0.0.0'
  opts.on( '-l', '--listen HOST', 'IP to listen on' ) do |host|
    options[:host] = host
  end
  
  options[:port] = 12345
  opts.on( '-p', '--port NUMBER', 'Port to listen on' ) do |num|
    options[:port] = num.to_i
  end
  
  options[:start_index] = 0
  opts.on( '-s', '--start NUMBER', 'Starting index number' ) do |num|
    options[:start_index] = num.to_i
  end
  
  options[:stop_index] = (1 << 32)
  opts.on( '-e', '--end NUMBER', 'Stopping index number, exclusive' ) do |num|
    options[:stop_index] = num.to_i
  end
  
  options[:block_size] = 8192
  opts.on( '-b', '--block-size NUMBER', 'Size of work block' ) do |num|
    options[:block_size] = num.to_i
  end
  
  options[:directory] = "blocks"
  opts.on( '-d', '--directory DIR', 'Directory to store responses for each work unit in' ) do |dir|
    options[:directory] = dir.gsub(/\/$/, '')
  end

  opts.on( nil, '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

remaining = optparse.parse(ARGV)

if __FILE__ == $0
  counters = {:next_block => 0, :repeat_queue => []}

  `install -d '#{options[:directory].gsub('\\', '\\\\').gsub('\'', '\\\'')}'`
  while File.exists?("#{options[:directory]}/#{counters[:next_block] * options[:block_size]}.block")
    counters[:next_block] += 1
  end

  EM.run do
    EM::start_server(options[:host], options[:port], SeedBatchServer, options, counters)
  end
end
