character_counts = Hash.new {0}

File.open(ARGV.shift, 'rb') do |file|
  file.each_line do |line|
    line = line.chomp.gsub(/^\s+/, '')
    count, word = line.split(' ', 2)
    word.split(//).each do |ch|
      character_counts[ch] += count.to_i
    end
  end
end

output_chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

output_chars.each do |ch|
  puts "#{ch},#{character_counts[ch]}"
end

