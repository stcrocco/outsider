require File.join(File.dirname(__FILE__), 'global_files_installer','global_files_installer')

Gem.post_install do |inst|
  global = GlobalFilesInstaller::Installer.new inst.spec.full_gem_path
  global.install_files
end

Gem.pre_uninstall do |uninst|
  global = GlobalFilesInstaller::Installer.new uninst.spec.full_gem_path
  global.uninstall_files
end