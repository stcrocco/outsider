require './spec/utils'

module GlobalInstallFeatures
  
# Returs the code which should be written in a gemspec file for a gem containing
# the file _files_
  def gemspec files = ['outsider_files'], data = {}
    data = {:version => '0.0.1', :name => 'global_install_test'}.merge data
    <<-EOS
      Gem::Specification.new do |s|
        s.name = #{data[:name].inspect}
        s.summary = 'a gem used to test the global_install gem'
        s.version = #{data[:version].inspect}
        s.files = #{files.inspect}
      end
    EOS
  end
  
# Builds a gem from the gemspec _file_ in the directory _dir_. The gem file will
# be created in _dir_
# 
# _options_ controls the amount of output from the `gem build` command. If the 
# :backtrace entry is *true* then the --bactrace option will be passed to gem. If
# :warnings is true, then messages written to standard error will be displayed
# 
# Returns the name of the gem file
  def build_gem dir, file = 'global_install_test.gemspec', options = {}
    gem_file = Dir.chdir(dir) do
      `gem build #{options[:backtrace] ? '--backtrace ' : ''}#{file}#{options[:warnings] ? ' 2>/dev/null' : ''}`
      Dir.entries('.').find{|f| File.extname(f) == '.gem'}
    end
    File.join dir, gem_file
  end
  
end

$gem_home = File.join Dir.tmpdir, random_string
ENV['GEM_HOME'] = $gem_home
ENV['OUTSIDER_RECORD_FILE'] = tmpfile random_string
puts "Building global_install gem"
`gem build outsider.gemspec`
puts "Installing global_install gem to #$gem_home"
gem = Dir.entries('.').find{|f| File.extname(f) == '.gem'}
`gem install #{gem}`

Kernel.at_exit do 
  FileUtils.rm_rf $gem_home
  Dir.glob('*.gem').each{|f| FileUtils.rm_rf f}
end

World(GlobalInstallFeatures)