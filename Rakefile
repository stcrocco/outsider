require 'rdoc/task'

RDoc::Task.new do |t|
  t.rdoc_files.include 'lib/**/*.rb'
  t.options << '-w2' << '-t' << 'Global Files Installer API'
  t.rdoc_dir = 'doc'
end

task :default => :rdoc