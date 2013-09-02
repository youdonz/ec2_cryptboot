load 'build_compression_table.rb'

file = ARGV.shift
baseline = (ARGV.shift || 0).to_i

tree = generate_tree(file, baseline)

print_tree tree

STDIN.each_line do |line|
  word = line.chomp
  puts word.split(//).map {|ch| scan_tree(tree, ch).length}.inject(0) {|s,i| s+i}
end
