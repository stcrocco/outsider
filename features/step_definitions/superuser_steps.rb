Given /^there's no global_install_config file in the current directory$/ do                                                                                                                               
  pending
  @gem_dir = mkdirtree '[test.rb, global_install_test.gemspec]', {'global_install_test.gemspec' => gemspec(['test.rb'])}
  @gem_file = build_gem @gem_dir
end

When /^I run the gem command$/ do                                                                                                                                                                         
  `gem install #{@gem_file}`
end                                                                                                                                                                                                       

Then /^nothing should be installed$/ do                                                                                                                                                                   
  pending # express the regexp above with the code you wish you had                                                                                                                                       
end                                                                                                                                                                                                       

Then /^no messages should be shown$/ do                                                                                                                                                                   
  pending # express the regexp above with the code you wish you had                                                                                                                                       
end                             

Given /^a global_install_config YAML file containing not containing ERB tags:$/ do |string|       
  ENV['GEM_HOME'] = $gem_home
  @installed_file_contents = {
    'file1.desktop' => '1',
    'file2.desktop' => '2'
    }
  contents = {'global_install_test.gemspec' => gemspec(%w[test.rb file1.desktop file2.desktop global_install_config]), 'global_install_config' => string}.merge @installed_file_contents
  @gem_dir = mkdirtree '[test.rb, global_install_test.gemspec, file1.desktop, file2.desktop, global_install_config]', contents
  @gem_file = build_gem @gem_dir
  @files_to_install = YAML.load(string)
  @files_to_remove = @files_to_install.entries
end            

Then /^the files should be installed in the given directories$/ do                                                                                                                                        
  @files_to_install.each_pair do |rel, abs|
    File.should exist(abs)
    File.read(abs).should == @installed_file_contents[rel]
  end
end              