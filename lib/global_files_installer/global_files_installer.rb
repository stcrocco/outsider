require 'yaml'
require 'fileutils'
require 'erb'

module GlobalFilesInstaller
  
  class Installer
    
# Creates a new instance
# 
# _dir_ is the directory where to look for the global_install_config file and the
# files to install
    def initialize dir
      @dir = dir
      @data = begin 
        YAML.load File.read(File.join(dir, 'global_install_config') )
      rescue SystemCallError
        {}
      end
    end
    
# Installs the files according to the instructions in the global_install_config
# file
    def install_files
      @data.each_pair do |k, v|
        dest = ERB.new(v).result
        file = File.join(@dir, k)
        FileUtils.cp file, dest if File.exist? file
      end
    end
    
  end
  
end