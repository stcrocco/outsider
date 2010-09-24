require 'fileutils'

require './spec/utils'
require 'global_files_installer/global_files_installer'

describe GlobalFilesInstaller::Installer do
  
  after do
    FileUtils.rm_rf @temp_dir if defined? @temp_dir
  end
  
  describe 'when created' do
    
    it 'scans the directory given as argument for a YAML file called global_install_config and loads it' do
      exp = {
        'file1' => '/path/to/file1',
        'file2' => '/path/to/file2',
        'file3' => '<%= ENV["HOME"] %>'
      }
      
      yaml = YAML.dump exp
      dir = mkdirtree ['global_install_config'], 'global_install_config' => yaml
      inst = GlobalFilesInstaller::Installer.new dir
      inst.instance_variable_get(:@data).should == exp
      @temp_dir = dir
    end
    
  end
  
  describe 'when installing files' do
    
    after do
      if defined? @files_to_install
        @files_to_install = @files_to_install.values if @files_to_install.is_a? Hash
        @files_to_install.each{|f| FileUtils.rm_f f}
      end
    end
    
    it 'installs the files in the directory passed to the constructor to the paths specified in the global_install_config file' do
      tree = %w[global_install_config file1 file2]
      @files_to_install = {
        'file1' => File.join(Dir.tmpdir, 'file1'),
        'file2' => File.join(Dir.tmpdir, 'file2')
      }
      @temp_dir = mkdirtree %w[global_install_config file1 file2], 'global_install_config' => YAML.dump(@files_to_install)
      inst = GlobalFilesInstaller::Installer.new @temp_dir
      inst.install_files
      File.should exist(@files_to_install['file1'])
      File.should exist(@files_to_install['file2'])
#       File.exist? @files_to_install['file1']
    end
    
  end
  
end