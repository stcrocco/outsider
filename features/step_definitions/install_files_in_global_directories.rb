require 'tempfile'

Given /^there's no global_install_config file in the current directory$/ do                                                                                                                               
  @gem_dir = mkdirtree '[test.rb, global_install_test.gemspec]', {'global_install_test.gemspec' => gemspec(['test.rb'])}
  @gem_file = build_gem @gem_dir
  @tmp_contents = Dir.entries(Dir.tmpdir).sort
  @log_file = File.join(Dir.tmpdir, random_string)
  @gem_command = "gem install #{@gem_file} 2>#{@log_file}"
end

When /^I run the gem command$/ do
  gem_command = defined?(@gem_command) ? @gem_command : "gem install #{@gem_file}"
  `#{gem_command}`
end                                                                                                                                                                                                       

Then /^nothing should be done/ do                                   
  (Dir.entries(Dir.tmpdir)-[File.basename(@log_file)]).sort.should == @tmp_contents
  log = File.read(@log_file)
  log.should be_empty
end                                                                                                                                                                                                       

Given /^an empty global_install_config file$/ do                                                                                                                                                          
  contents = {'global_install_test.gemspec' => gemspec(%w[test.rb global_install_config])}
  @gem_dir = mkdirtree '[test.rb, global_install_test.gemspec, global_install_config]', contents
  @gem_file = build_gem @gem_dir
  @tmp_contents = Dir.entries(Dir.tmpdir).sort
  @log_file = File.join(Dir.tmpdir, random_string)
  @gem_command = "gem install #{@gem_file} 2>#{@log_file}"
end        

Given /^a global_install_config YAML file not containing ERB tags:$/ do |string|       
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

Given /^a global_install_config YAML file containing ERB tags:$/ do |string|                                                                                                                              
  ENV['GEM_HOME'] = $gem_home
  @installed_file_contents = {
    'file1' => '1',
    'file2' => '2'
  }
  contents = {'global_install_test.gemspec' => gemspec(%w[test.rb file1 file2 global_install_config]), 'global_install_config' => string}.merge @installed_file_contents
  @gem_dir = mkdirtree '[test.rb, global_install_test.gemspec, file1, file2, global_install_config]', contents
  @gem_file = build_gem @gem_dir
  @files_to_install = {
    'file1' => File.join(Dir.tmpdir, 'file1'),
    'file2' => '/tmp/file2'
    }
  @files_to_remove = @files_to_install.entries
end                          

Then /^the files should be installed in directories obtained evaluating the ERB tags$/ do                                                                                                                 
  Then 'the files should be installed in the given directories'
end

Given /^a global_install_config YAML file with:$/ do |text|
  contents = {'global_install_test.gemspec' => gemspec(%w[test.rb file2 global_install_config]), 'global_install_config' => text}
  @gem_dir = mkdirtree '[test.rb, global_install_test.gemspec, file2, global_install_config]', contents
  @gem_file = build_gem @gem_dir
  @files_to_install = YAML.load(text)
  @files_to_remove = @files_to_install.entries
end

Given /^that ([^\s]+) doesn't exist in the gem directory/ do |file|
end

Then /^only the existing files should be installed$/ do
  @files_to_install.each_pair do |rel, abs|
    if File.exist? File.join(@gem_dir, rel)
      File.should exist(abs)
    end
  end
end

Given /^a global_install_config YAML file containing nonexisting directories:$/ do |text|                                                                                                               
  contents = {'global_install_test.gemspec' => gemspec(%w[test.rb file1 file2 global_install_config]), 'global_install_config' => text}
  @gem_dir = mkdirtree '[test.rb, global_install_test.gemspec, file1, file2, global_install_config]', contents
  @gem_file = build_gem @gem_dir
  @files_to_install = YAML.load(text)
  @files_to_remove = @files_to_install.entries
  FileUtils.rm_rf '/tmp/global_files_installer_testdir1'
end                                                                                                                                                                                                       

Then /^the needed directories should be created with default permissions$/ do                                                   
  @files_to_install.each_pair do |rel, abs|
    File.should exist(abs)
  end
end