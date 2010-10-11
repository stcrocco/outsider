# Copyright (c) 2010 Stefano Crocco <stefano.crocco@alice.it>
# Distributed under the terms of the Ruby license

require 'yaml'
require 'fileutils'
require 'erb'
require 'pathname'

# Namespace for the Outsider gem
module Outsider
  
  # Class which installs and uninstalls files
  class Installer
    
    # The path of the record file to use if the +OUTSIDER_RECORD_FILE+
    # environment variable is unset
    DEFAULT_RECORD_FILE = File.join '/', 'var', 'lib', 'outsider', 'installed_files'
    
    # Exception raised when the record file is not a valid record file
    class InvalidRecordFile < StandardError
      
      # The path of the invalid record file
      attr_reader :file
      
      # Creates a new instance
      # 
      # _file_ is the name of the invalid record file, while _msg_ is a message
      # describing why the file is invalid
      def initialize file, msg
        @file = file
        super msg + ": #{@file}"
      end
      
    end
    
    # Creates a new instance
    # 
    # _dir_ is the directory where to look for the outsider_files file and the
    # files to install
    def initialize dir
      @gem_dir = dir
      @user_install = dir.start_with? ENV['HOME']
      @data = begin 
        YAML.load File.read(File.join(dir, 'outsider_files'))
      rescue SystemCallError
      end
      # If either the outsider_files file doesn't exist or it's empt
      # (in which case YAML.load returns false), set @data to an empty hash
      @data ||={}
      @gem_name = File.basename(dir)
    end
    
    # Installs the files according to the instructions in the outsider_files
    # file
    # 
    # Returns *nil*
    def install_files
      installed_files = []
      @data.each_pair do |k, v|
        dest = install_destination v
        dest = File.join dest, File.basename(k) if dest.end_with? '/'
        orig = File.join(@gem_dir, k)
        installed_files << [orig, dest] if install_file orig, dest
      end
      record_installed_files installed_files unless installed_files.empty?
      nil
    end
    
    # Uninstalls the files associated with the gem in the current directory
    # 
    # If any of those file is owned also by other gems (including by other versions
    # of the same gem), then the files are only uninstalled if the gem is the last to
    # have been installed. In this case, the file belonging to the previously installed
    # gem is copied. If that file doesn't exist, then the one previous to it is tried,
    # and so on.
    # 
    # The record is updated to remove all mentions of the gem being uninstalled
    # 
    # Returns *nil*
    def uninstall_files
      rec_file = record_file
      files = begin read_record_file rec_file
      rescue InvalidRecordFile then nil
      end
      return unless files
      files.each_pair do |f, data|
        gem_data = data.find{|i| i[:gem] == @gem_name}
        next unless gem_data
        if data.last[:gem] == @gem_name
          FileUtils.rm_f f 
          data[0..-2].reverse_each do |d|
            if File.exist? d[:origin]
              FileUtils.cp d[:origin], f 
              break
            end
          end
        end
        data.delete gem_data
      end
      files.delete_if{|k, v| v.empty?}
      write_record_file rec_file, files
      nil
    end
    
    private
    
    # The path of the record file
    # 
    # In case of a user install, the file is always <tt>ENV['HOME']/.outsider/installed_files</tt>.
    # In case of a global install, instead, the following algorithm is used:
    # * if the +OUTSIDER_RECORD_FILE+ environment variable is set,
    #   its value is used
    # * otherwise, if the file /etc/outsider.conf exists and isn't
    #   empty, the name of the record file is read from there
    # * if all the above fails, then DEFAULT_RECORD_FILE is used
    # 
    # Returns the name of the record file to use 
    def record_file
      if @user_install then File.join ENV["HOME"], '.outsider', 'installed_files'
      elsif ENV['OUTSIDER_RECORD_FILE'] then ENV['OUTSIDER_RECORD_FILE']
      elsif File.exist?('/etc/outsider.conf')
        file = File.read '/etc/outsider.conf'
        file.empty? ? DEFAULT_RECORD_FILE : file
      else DEFAULT_RECORD_FILE
      end
    end

    # Creates the installation path for an entry in the +outsider_files+ file
    # 
    # _data_ is the entry and can be a string or an array with two elements. If
    # doing a global install, then the destination file is found simply by passing the
    # string or the first entry of the array through ERB.
    # 
    # In case of a user install, things are a bit more complex and change depending
    # on whether _data_ is an array or a string
    # * if it is an array, then the second entry will be used as path, after passing
    #   it through ERB. If it isn't an absolute file, it'll be considered relative
    #   to the user's home page.
    # * if it is a string, what ERB returns will be considered a path relative to the user's
    #   home directory. There are a few exceptions, however. If the path starts
    #   with /usr/, /usr/local/, /var/, /opt/ or /etc/ then that directory will be
    #   replaced with the home directory. If it starts with /usr/share or /usr/local/share,
    #   that directory will be replaced with <tt>ENV["HOME"]/.local/share</tt>.
    #   If it starts with /bin/, /sbin/ or /usr/sbin/, that directory will be 
    #   replaced by <tt>ENV["HOME"]/bin</tt>.
    #   
    # Returns the destination path
    def install_destination data
      home = ENV['HOME']
      if data.is_a? Array then path = data[@user_install ? 1 : 0]
      else path = data
      end
      path = ERB.new(path).result
      if @user_install and data.is_a? Array
        File.expand_path path, home
      elsif @user_install
        replacements = [
          [%r{^/bin/}, File.join(home, 'bin')],
          [%r{^/sbin/}, File.join(home, 'bin')],
          [%r{^/usr/sbin/}, File.join(home, 'bin')],
          [%r{^/usr/local/share/}, File.join(home, '.local', 'share')],
          [%r{^/usr/share/}, File.join(home, '.local', 'share')],
          [%r{^/usr/local/}, home],
          [%r{^/usr/}, home],
          [%r[^/var/], home],
          [%r[^/opt/], home],
          [%r[^/etc/], home],
          [%r{^~/}, home],
          [%r{^(?=.)}, home]
        ]
        match = replacements.find{|reg, _| path.match reg}
        File.join match[1], path.sub(match[0], '')
      else path
      end
    end
    
# Copies the file _orig_ to _dest_
# 
# If the path to _dest_ doesn't exist, then the missing directories are created.
# If the file _orig_ doesn't exist, nothing is done.
# 
# Returns _dest_ if the file was installed successfully and *nil* if _orig_ didn't
# exist. Raises a subclass of SystemCallError if the file couldn't be copied, for
# example due to wrong permissions
    def install_file orig, dest
      if File.exist? orig
        begin FileUtils.cp orig, dest
        rescue SystemCallError
          path = Pathname.new dest
          path.descend do |pth|
            if pth.exist? then next
            elsif pth == path
              FileUtils.cp orig, dest
            else FileUtils.mkdir pth.to_s
            end
          end
        end
        puts "Installed #{orig.sub(%r{^#{Regexp.quote @gem_dir}/}, '')} to #{dest}"
        dest
      else nil
      end
    end
    
# Adds the given files to the record file
# 
# The path to the record file is given by the OUTSIDER_RECORD_FILE
# environment variable. If the variable is unset, +/var/lib/outsider/installed_files+
# is used.
# 
# If the record file doesn't exist, it's created, together with any missing directory.
# 
# If a file with the same name as the record file exists but it's not a valid record
# file, it will be renamed by appending a <tt>-n</tt> suffix, where _n_ is a number,
# and a new record file will be created. A warning will be issued in this case
# 
# Returns *nil*
    def record_installed_files files
      file = record_file
      begin 
        data = read_record_file file
        data ||= {}
      rescue InvalidRecordFile 
        data = rename_invalid_record_file file
        retry
      end
      files.each do |f| 
        data[f[1]] ||= []
        d = data[f[1]]
        d.reject!{|h| h[:gem] == @gem_name}
        d << {:gem => @gem_name, :origin => File.join(@gem_dir, f[0])}
      end
      write_record_file file, data
      nil
    end
    
# Write data to a given record file
# 
# _file_ is the name of the record file and will be created, if it doesn't exist,
# together with the directory composing its path. _data_ is the hash to write.
# 
# Returns *nil*
    def write_record_file file, data
      record_dir = File.dirname(file)
      FileUtils.mkdir_p record_dir unless File.directory? record_dir
      File.open(file, 'w'){|f| YAML.dump(data, f)}
      nil
    end
    
# Reads the files installed from the given record file
# 
# If the file isn't a valid record file, InvalidRecordFile is raised.
# 
# _file_ is the name of the record file
# 
# Returns the hash contained in the record file or *nil* if the file doesn't exist
    def read_record_file file
      data = begin YAML.load File.read(file)
      rescue ArgumentError then raise InvalidRecordFile.new file, "Invalid YAML file"
      rescue SystemCallError 
        return nil if !File.exist? file
        raise
      end
      unless valid_record_contents? data
        raise InvalidRecordFile.new file, "Invalid record file format" 
      end
      data
    end
    
# Checks whether the given object is valid content for a record file
# 
# Returns *true* if _data_ is a legitimate content for a record file and *false*
# otherwise
# 
# A valid record file has the following format (in YAML):
# 
#  /path/to/installed_file_1:
#   - {:gem: name_and_version_of_gem1, :origin: path/to/original/file1}
#   - {:gem: name_and_version_of_gem2, :origin: path/to/original/file2}
#  /path/to/installed_file_2
#   - {:gem: name_and_version_of_gem3, :origin: path/to/original/file3}
#   - {:gem: name_and_version_of_gem4, :origin: path/to/original/file4}
    def valid_record_contents? data
      return false unless data.is_a? Hash
      data.each_pair do |dest, v|
        return false unless dest.is_a? String and v.is_a? Array
        v.each do |gem|
          return false unless gem.is_a? Hash
          return false unless gem[:gem].is_a? String and gem[:origin].is_a? String
        end
      end
      true
    end
    
# Renames the invalid record file _file_ giving it a new unique name and issues a
# warning
# 
# Returns *nil*
    def rename_invalid_record_file file
      n = 1
      n+=1 while File.exist?( file + "-#{n}")
      new_file = file + "-#{n}"
      warn "The file #{file} isn't a valid record file and will be moved to #{new_file}"
      FileUtils.mv file, new_file
      nil
    end
    
  end
  
end