load 'build_compression_table.rb'

tree = generate_tree(ARGV.shift)

print_tree tree

STDIN.each_line do |line|
  word = line.chomp
  puts word.split(//).map {|ch| scan_tree(tree, ch).length}.inject(0) {|s,i| s+i}
end
