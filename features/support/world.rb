require './spec/utils'

module GlobalInstallFeatures
  
# Returs the code which should be written in a gemspec file for a gem containing
# the file _files_
  def gemspec files = ['global_install_config']
    <<-EOS
      Gem::Specification.new do |s|
        s.name = 'global_install_test'
        s.summary = 'a gem used to test the global_install gem'
        s.version = '0.0.0'
        s.files = #{files.inspect}
      end
    EOS
  end
  
# Builds a gem from the gemspec _file_ in the directory _dir_. The gem file will
# be created in _dir_
# 
# Returns the name of the gem file
  def build_gem dir, file = 'global_install_test.gemspec'
    gem_file = Dir.chdir(dir) do
      `gem build #{file} 2>/dev/null`
      Dir.entries('.').find{|f| File.extname(f) == '.gem'}
    end
    File.join dir, gem_file
  end
  
end

$gem_home = File.join Dir.tmpdir, random_string
ENV['GEM_HOME'] = $gem_home
puts "Building global_install gem"
`gem build global_install_files.gemspec`
puts "Installing global_install gem to #$gem_home"
gem = Dir.entries('.').find{|f| File.extname(f) == '.gem'}
`gem install #{gem}`

Kernel.at_exit do 
  FileUtils.rm_rf $gem_home
  Dir.glob('*.gem').each{|f| FileUtils.rm_rf f}
end

World(GlobalInstallFeatures)