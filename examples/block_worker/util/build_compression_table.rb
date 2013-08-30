def build_subtree(branch)
  result = []
  branch.each do |subbranch|
    if subbranch.kind_of?(Array)
      subtree = build_subtree(subbranch)
      result << subtree.length
      result += subtree
    else
      result += [0, subbranch.getbyte(0)]
    end
  end
  
  result
end

def print_tree(tree, path = "")
  if tree.kind_of?(Array)
    print_tree(tree.first, path + "0")
    print_tree(tree.last, path + "1")
  else
    puts "  " * path.length + path + " = " + tree.to_s
  end
end

def scan_tree(tree, character, path = "")
  if tree.kind_of?(Array)
    scan_tree(tree.first, character, path + "0") || scan_tree(tree.last, character, path + "1")
  else
    if tree == character
      path
    else
      nil
    end
  end
end

def generate_tree(frequency_file)
  symbols = []
  File.open(frequency_file, 'r') do |file|
    file.each_line do |line|
      symbol, weight = line.chomp.split(",")
      symbols << [symbol, weight.to_f]
    end
  end

  while symbols.length > 1
    symbols.sort_by! {|pair| 0 - pair[1]}
    second = symbols.pop
    first = symbols.pop
    symbols << [[first[0], second[0]], first[1] + second[1]]
  end

  symbols.first.first
end

def test_tree(ctree, tree, path = "")
  if tree.kind_of?(Array)
    test_tree(ctree, tree.first, path + "0")
    test_tree(ctree, tree.last, path + "1")
  else
    bits = path.split(//).map {|e| e == "1"}
    
    idx = 0
    done = false
    
    while !bits.empty?
      if bits.shift
        offs = ctree[idx]
        idx += offs > 0 ? offs + 1 : 2
      end
      
      prev = ctree[idx]
      idx += 1
      if prev == 0
        done = true
        break
      end
    end
    
    if !done
      puts "Failed to complete with path #{path}"
    elsif ctree[idx] != tree.getbyte(0)
      puts "Wrong character for path #{path}: expected #{tree}, got #{ctree[idx].chr}"
    end
  end
end

if $0 == __FILE__
  tree = generate_tree(ARGV.shift)

  print_tree tree

  ctree = build_subtree(tree)
  p ctree

  test_tree ctree, tree
end