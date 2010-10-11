require 'rdoc/task'

RDoc::Task.new do |t|
  t.rdoc_files.include 'lib/**/*.rb', 'README.rdoc', 'CHANGES.rdoc'
  t.options << '-w2' << '-t' << 'Outsider API'
  t.rdoc_dir = 'doc'
end

task :default => :rdoc
