require 'fileutils'

After do
  FileUtils.rm_rf @gem_dir if defined? @gem_dir
  if defined? @files_to_remove
    @files_to_remove.each{ |f| FileUtils.rm_rf f}
  end
end