Gem::Specification.new do |s|
  s.name = 'outsider'
  s.author = 'Stefano Crocco'
  s.email = 'stefano.crocco@alice.it'
  s.summary = 'rubygems plugin to allow a gem to install files outside its own directory'
  s.files = %w[lib/rubygems_plugin.rb lib/outsider/outsider.rb README.rdoc]
  s.version = '0.0.2'
  s.homepage = "http://github.com/stcrocco/outsider"
  s.required_ruby_version = '>=1.8.7'
end
