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
    
    it 'does nothing if the global_install_config file doesn\'t exist' do
      dir = mkdirtree []
      @temp_dir = dir
      lambda{GlobalFilesInstaller::Installer.new dir}.should_not raise_error
    end
    
  end
  
  describe 'when installing files' do
    
    after do
      if defined? @files_to_install
        @files_to_install = @files_to_install.values if @files_to_install.is_a? Hash
        @files_to_install.each{|f| FileUtils.rm_rf f}
      end
    end
    
    context 'The global_install_config file doesn\'t contain ERB tags' do
      
      it 'installs the files in the given directories' do
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
      end
      
    end
    
    context 'The global_install_config file contains ERB tags' do
      
      it 'installs the files in the directories obtained by evaluating the ERB tags' do
        tree = %w[global_install_config file1 file2]
        @files_to_install = {
          'file1' => File.join(Dir.tmpdir, 'file1'),
          'file2' => File.join(Dir.tmpdir, 'file2')
        }
        global_install_config = <<-EOS
file1: <%= require 'tempfile';File.join Dir.tmpdir, 'file1' %>
file2: /tmp/file2
        EOS
        @temp_dir = mkdirtree %w[global_install_config file1 file2], 'global_install_config' => global_install_config
        inst = GlobalFilesInstaller::Installer.new @temp_dir
        inst.install_files
        File.should exist(@files_to_install['file1'])
        File.should exist(@files_to_install['file2'])
      end
      
    end
    
    it 'skips files which do not exist in the gem directory' do
#       tree = %w[global_install_config file1 file2]
      @files_to_install = {
        'file1' => File.join(Dir.tmpdir, 'file1'),
        'file2' => File.join(Dir.tmpdir, 'file2')
      }
      @temp_dir = mkdirtree %w[global_install_config file2], 'global_install_config' => YAML.dump(@files_to_install)
      @files_to_install.delete 'file1'
      inst = GlobalFilesInstaller::Installer.new @temp_dir
      lambda{inst.install_files}.should_not raise_error
      File.should exist(@files_to_install['file2'])
    end
    
    it 'creates any needed directories with default permissions' do
#       tree = %w[global_install_config file1 file2]
      missing_dir = random_string
      missing_dir_full = File.join(Dir.tmpdir, missing_dir)
      missing_subdir = random_string
      missing_subdir_full = File.join missing_dir_full, missing_subdir
      @files_to_install = {
        'file1' => File.join(missing_subdir_full, 'file1'),
        'file2' => File.join(Dir.tmpdir, 'file2')
      }
      @temp_dir = mkdirtree %w[global_install_config file1 file2], 'global_install_config' => YAML.dump(@files_to_install)
      inst = GlobalFilesInstaller::Installer.new @temp_dir
      inst.install_files
      @files_to_install.each_value do |dest|
        File.should exist(dest)
      end
      @files_to_install = @files_to_install.values + [missing_dir_full]
      File.should be_directory(missing_dir_full)
      File::Stat.new(missing_dir_full).mode.to_s(8)[-3..-1].should == '700'
      File.should be_directory(missing_subdir_full)
      File::Stat.new(missing_subdir_full).mode.to_s(8)[-3..-1].should == '700'
    end

  end
  
end