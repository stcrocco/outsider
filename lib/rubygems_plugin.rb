require File.join(File.dirname(__FILE__), 'outsider','outsider')

Gem.post_install do |inst|
  global = Outsider::Installer.new inst.spec.full_gem_path
  global.install_files
end

Gem.pre_uninstall do |uninst|
  global = Outsider::Installer.new uninst.spec.full_gem_path
  global.uninstall_files
end