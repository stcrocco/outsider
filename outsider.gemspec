Gem::Specification.new do |s|
  s.name = 'outsider'
  s.author = 'Stefano Crocco'
  s.email = 'stefano.crocco@alice.it'
  s.summary = 'rubygems plugin to allow a gem to install files outside its own directory'
  s.files = %w[lib/rubygems_plugin.rb lib/outsider/outsider.rb README.rdoc]
  s.version = '0.0.2'
  s.homepage = "http://github.com/stcrocco/outsider"
  s.required_ruby_version = '>=1.8.7'
  s.post_install_message = <<-EOS
If you have other versions of this gem installed, you're advised to remove them
before installing other gems.

If you don't do this, each version of Outsider you have installed will install
or remove the files specified by gems you install or uninstall. This shouldn't
cause problems, but, to be on the safe side, it's better avoided.
  EOS
end
