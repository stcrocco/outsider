require 'yaml'
require 'fileutils'
require 'erb'
require 'pathname'

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
        if File.exist? file
          begin FileUtils.cp file, dest
          rescue SystemCallError
            path = Pathname.new dest
            path.descend do |pth|
              if pth.exist? then next
              elsif pth == path
                FileUtils.cp file, dest
              else
                FileUtils.mkdir pth.to_s
                FileUtils.chmod 0700, pth.to_s
              end
            end
          end
        end
      end
    end
    
  end
  
end