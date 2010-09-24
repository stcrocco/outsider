require 'yaml'
require 'fileutils'

module GlobalFilesInstaller
  
  class Installer
    
# Creates a new instance
# 
# _dir_ is the directory where to look for the global_install_config file and the
# files to install
    def initialize dir
      @dir = dir
      @data = YAML.load File.read(File.join(dir, 'global_install_config') )
    end
    
# Installs the files according to the instructions in the global_install_config
# file
    def install_files
      @data.each_pair do |k, v|
        FileUtils.cp File.join(@dir, k), v
      end
    end
    
  end
  
end