require 'yaml'
require 'tempfile'

# Generates a random string containing _size_ alphanumeric characters
def random_string size = 10
  letters = ('A'..'Z').to_a + ('a'..'z').to_a + ('1'..'0').to_a
  size.times.map{letters[rand(letters.size)]}.join
end

# Creates a temporary directory tree
# 
# The directory tree is created under a subdirectory of the directory _base_ and
# its name is randomly generated (it's made of 10 random alphanumeric characters).
# 
# Each subdirectory in the tree is represented by a hash with a single entry. The
# key of this entry is the name of the subdirectory, while the value is an array
# of strings and hashes, which represent respectively files and subdirectories.
# If a directory contains a single element, you can omit the array.
# 
# The toplevel directory of the tree is represented by a hash as the ones described
# above, but having *nil* as its only key. Alternatively, you can simply use an
# array with the directory's contents.
# 
# The contents of the directory tree are specified, according to the rules above,
# in _tree_, which can be either a hash, an array or a string representing a hash
# or array in YAML format.
# 
# By default, files in the directory tree are created empty. If a file should have
# a given content, it must be specified in the _contents_ hash. This hash as the
# names of files (relative to the top of the tree) as keys and their contents as
# values. Any file not listed here will be empty.
# 
# Returns the name of the randomly-named subdirectory.
# 
# EXAMPLE
# Using as first argument the array (written here in YAML format)
# 
# - dir1:
#   - dir2:
#     - file1
#     - file2
#     - {dir3: [file3]}
# - {dir4: file4}
# - file5
# 
# gives the following directory tree:
# 
#   dir1/
#     dir2/
#       file1
#       file2
#       dir3/
#         file3
#   dir4/
#     file4
#   file5
def mkdirtree tree, contents = {}, base = Dir.tmpdir
  temp_dir = random_string
  dirs = []
  files = []
  tree = YAML.load(tree) if tree.is_a? String
  if tree.is_a? Array then tree = {temp_dir => tree}
  elsif tree.is_a? Hash
    tree[temp_dir] = tree[nil]
    delete tree[nil]
  end
  process_entry = lambda do |base_dir, data|
    if data.is_a? Hash
      dir = data.keys[0] || ''
      full_dir = File.join base_dir, dir
      dirs << full_dir
      dir_contents = Array(data.values[0])
      dir_contents.each{|v| process_entry.call full_dir, v}
    elsif data.is_a?(String) then files << File.join(base_dir, data)
    end
  end
  process_entry.call base, tree
  dirs.each{|d| FileUtils.mkdir d}
  temp_dir = File.join base, temp_dir
  contents.keys.each do |k|
    new_key = File.join temp_dir, k
    contents[new_key] = contents[k]
    contents.delete k
  end
  files.each do |f|
    if contents[f] then File.open(f, 'w'){|out| out.write contents[f]}
    else `touch #{f}`
    end
  end
  temp_dir
end

# RSpec::Matchers.define 