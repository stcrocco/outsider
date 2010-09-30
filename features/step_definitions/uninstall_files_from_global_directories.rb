require 'fileutils'
require 'cucumber/rspec/doubles'

Given /^a gem with some files globally installed in a directory I have write access to$/ do
  record_file = File.join  Dir.tmpdir, random_string
  ENV["OUTSIDER_RECORD_FILE"] = record_file
  config = <<-EOS
file1: #{File.join Dir.tmpdir, 'file1'}
file2: #{File.join Dir.tmpdir, 'file2'}
  EOS
  contents = {'outsider_test.gemspec' => gemspec(%w[test.rb outsider_files file1 file2], :name => 'outsider_test'), 'outsider_files' => config}
  @gem_dir = mkdirtree '[test.rb, outsider_test.gemspec, file1, file2, outsider_files]', contents
  @gem_file = build_gem @gem_dir, 'outsider_test.gemspec'
  `gem install #{@gem_file}`
  @files_to_remove = []
  %w[file1 file2].each do |f| 
    file = File.join '/tmp', f
    @files_to_remove << file
    `touch #{file}`
  end
  @files_to_uninstall = %w[/tmp/file1 /tmp/file2]
  @gem_name = 'outsider_test'
end                                                                                                                                                                                                       

Given /^that files aren't shared with another gem$/ do                                                                                                                                                                                                                                                                                   
end                                                                                                                                                                                                       

When /^I run the gem uninstall command$/ do
  `gem uninstall #{@gem_name}`
end                                                                                                                                                                                                       

Then /^the files should be removed$/ do                                                                                                                                                                   
  @files_to_uninstall.each{|f| p f;File.should_not exist(f)}
end