require 'fileutils'
require 'tempfile'

require './spec/utils'
require 'outsider/outsider'

describe Outsider::Installer do
  
  def install_files_list *files
    res = files.inject({}) do |res, f|
      if f.is_a? Hash then res.merge! f
      else 
        res[f] = tmpfile f
        res
      end
    end
  end

  def make_gem_dir to_install, outsider_files = nil, base_dir = nil
    if to_install.is_a? Hash
      outsider_files ||= YAML.dump(to_install)
      to_install = to_install.keys
    end
    if base_dir
      mkdirtree ['outsider_files'] + to_install, {'outsider_files' => outsider_files}, base_dir
    else mkdirtree ['outsider_files'] + to_install, 'outsider_files' => outsider_files
    end
  end
  
  def gem_path dir = nil, name = nil
    dir ||= @gem_dir
    name ||= @gem_name
    File.join dir, name
  end
  
  def in_gem file
    File.join @gem_dir, file
  end
  
  def make_install_map files
    files.inject([]) do |res, f|
      res << [File.basename(f), f]
    end
  end
  
# Creates the record hash for the given files
#
# by_gem is a hash of the files to record sorted by gem. The keys are the full gem
# paths (including the directory), while the values are array of either strings
# or hashes. In the case of hashes, the keys are the destinations, while the values
# are the origin files, relative to the gem directory. In the case of strings,
# they're interpreted as the origin files and the destination file is obtained by
# prepending /tmp/ to it
# 
# If yaml is true, the YAML dump of the resulting hash is returned, otherwise the
# hash itself is returned
  def create_record by_gem, yaml = false
    by_file = by_gem.inject({}) do |res, data|
      gem, files = data
      gem_dir, gem = gem, File.basename(gem)
      files = files.map do |f|
        f.is_a?(Hash) ? f : [tmpfile(f), File.join(gem_dir, f)]
      end
      files.each{|f| (res[f[0]] ||= []) << {:gem => gem, :origin => f[1]}}
      res
    end
    yaml ? YAML.dump(by_file) : by_file
  end
  
  after do
    FileUtils.rm_rf @gem_dir if defined? @gem_dir
  end
  
  before do
    ENV["OUTSIDER_RECORD_FILE"] = tmpfile 'outsider_record.yaml'
  end
  
  describe 'when created' do
    
    it 'scans the directory given as argument for a YAML file called outsider_files and loads it' do
      exp = {
        'file1' => '/path/to/file1',
        'file2' => '/path/to/file2',
        'file3' => '<%= ENV["HOME"] %>'
      }
      
      yaml = YAML.dump exp
      dir = mkdirtree ['outsider_files'], 'outsider_files' => yaml
      inst = Outsider::Installer.new dir
      inst.instance_variable_get(:@data).should == exp
      @gem_dir = dir
    end
    
    it 'does nothing if the outsider_files file doesn\'t exist' do
      dir = mkdirtree []
      @gem_dir = dir
      lambda{Outsider::Installer.new dir}.should_not raise_error
    end
    
    it 'does nothing if the outsider_files file is empty' do
      dir = mkdirtree ['outsider_files']
      @gem_dir = dir
      inst = nil
      lambda{inst = Outsider::Installer.new dir}.should_not raise_error
      inst.instance_variable_get(:@data).should == {}
    end
    
  end
  
  describe 'when installing files' do
    
    before do
      $stdout = StringIO.new '', 'r+'
    end
    
    after do
      $stdout = STDOUT
      if defined? @files_to_install
        @files_to_install = @files_to_install.values if @files_to_install.is_a? Hash
        @files_to_install.each{|f| FileUtils.rm_rf f}
      end
    end
    
    RSpec::Matchers.define :have_installed do |files|
      match do |inst|
        files = files.values if files.is_a? Hash
        @expected_files = files.dup
        @found_files = files.select{|f| File.exist? f}
        @expected_files.size == @found_files.size
      end
      failure_message_for_should do |inst|
        installed_msg = @found_files.empty? ? "installed no file" : "only installed #{@found_files.join ', '}"
        "expected #{inst} to install #{@expected_files.join ', '} but it #{installed_msg}"
      end
    end
    
    context 'The outsider_files file doesn\'t contain ERB tags' do    
      
      it 'installs the files in the given directories' do
        @files_to_install = install_files_list 'file1', 'file2'
        @gem_dir = make_gem_dir @files_to_install
        inst = Outsider::Installer.new @gem_dir
        inst.install_files
        inst.should have_installed @files_to_install
      end
      
    end
    
    context 'The outsider_files file contains ERB tags' do
      
      it 'installs the files in the directories obtained by evaluating the ERB tags' do
        @files_to_install = install_files_list 'file1', 'file2'
        outsider_files = <<-EOS
file1: <%= require 'tempfile';File.join Dir.tmpdir, 'file1' %>
file2: /tmp/file2
        EOS
        @gem_dir = mkdirtree %w[outsider_files file1 file2], 'outsider_files' => outsider_files
        inst = Outsider::Installer.new @gem_dir
        inst.install_files
        inst.should have_installed(@files_to_install)
      end
      
    end
    
    context 'The entry corresponding to the file is an array' do
      
      it 'install the files in the path contained in position 0 in the array' do
        data = {'file1' => %w[/tmp/file1 /other/path/file1]}
        @files_to_install = {'file1' => '/tmp/file1'}
        @gem_dir = make_gem_dir @files_to_install, YAML.dump(@files_to_install)
        inst = Outsider::Installer.new @gem_dir
        inst.install_files
        inst.should have_installed(@files_to_install)
      end
      
    end
    
    it 'adds the name of the original file (without directory) if the destination path ends in a / after expanding ERB tags' do
      @files_to_install = install_files_list 'file2'
      @files_to_install['file1'] = tmpfile 'my_dir', 'file1'
      outsider_files = <<-EOS
      file1: <%= require 'tempfile';File.join Dir.tmpdir, 'my_dir/'%>
      file2: /tmp/
      EOS
      @gem_dir = mkdirtree %w[outsider_files file1 file2], 'outsider_files' => outsider_files
      inst = Outsider::Installer.new @gem_dir
      inst.install_files
      inst.should have_installed(@files_to_install)
    end
    
    it 'skips files which do not exist in the gem directory' do
      @files_to_install = install_files_list 'file1'
      outsider_files = YAML.dump(@files_to_install.merge({'file1' => '/tmp/file1'}))
      @gem_dir = make_gem_dir @files_to_install, outsider_files
      inst = Outsider::Installer.new @gem_dir
      lambda{inst.install_files}.should_not raise_error
      inst.should have_installed(@files_to_install)
    end
    
    it 'creates any needed directories with default permissions' do
      missing_dir = tmpfile random_string
      missing_subdir = File.join missing_dir, random_string
      @files_to_install = {
        'file1' => File.join(missing_subdir, 'file1'),
        'file2' => tmpfile('file2')
      }
      @gem_dir = make_gem_dir @files_to_install
      inst = Outsider::Installer.new @gem_dir
      inst.install_files
      installed = @files_to_install
      # We have to add the missing_dir_full to the @files_to_install variable so
      # it gets removed in the after step
      @files_to_install = @files_to_install.values << missing_dir
      inst.should have_installed(installed)
      [missing_dir, missing_subdir].each{|d| File.should be_directory(missing_dir)}
    end

    it 'calls the #record_installed_files method' do
      @files_to_install = install_files_list 'file1', 'file2'
      @gem_dir = make_gem_dir @files_to_install
      inst = Outsider::Installer.new @gem_dir
      exp = @files_to_install.inject([]) do |res, data|
        res << [File.join(@gem_dir, data[0]), data[1]]
      end
      inst.should_receive(:record_installed_files).once.with(exp)
      inst.install_files
    end
    
    context 'when doing a user install' do
      
      before do
        @home = tmpfile random_string
        ENV['HOME'] = @home
        FileUtils.mkdir @home
      end
      
      after do
        FileUtils.rm_rf @home
      end
      
      context 'the entry associated with the file in the file list is an array with two entries' do
        
        it 'installs the file in the second entry of the array (relative to the user\'s home directory) if that entry is a relative path' do
          @files_to_install = [File.join(@home, 'destination/path/file1')]
          @gem_dir = make_gem_dir ['file1'], YAML.dump('file1' => %w[/usr/some/path/file1 destination/path/file1]), @home
          inst = Outsider::Installer.new @gem_dir
          inst.install_files
          inst.should have_installed @files_to_install
        end
        
        it 'installs the file in the second entry of the array if that entry is an absolute path' do
          @files_to_install = [File.join(@home, 'destination/path/file1')]
          @gem_dir = make_gem_dir ['file1'], YAML.dump('file1' => %W[/usr/some/path/file1 #{File.join @home, 'destination/path/file1'}]), @home
          inst = Outsider::Installer.new @gem_dir
          inst.install_files
          inst.should have_installed @files_to_install
        end
        
      end
      
      context 'the entry associated with the file in the file list is a string' do
        
        it 'installs the file under ENV["HOME"]/.local/share if the installation directory is a subdirectory of /usr/share or /usr/local/share' do
          @original_dest = %w[/usr/share/file1 /usr/local/share/file2]
          @files_to_install = %w[.local/share/file1 .local/share/file2].map{|f| File.join @home, f}
          config = @original_dest.inject({}){|res, f| res[File.basename(f)] = f; res}
          @gem_dir = make_gem_dir @files_to_install.map{|f| File.basename(f)}, YAML.dump(config), @home
          inst = Outsider::Installer.new @gem_dir
          inst.install_files
          inst.should have_installed @files_to_install
        end
        
        it 'installs the file under ENV["HOME"]/bin if the installation directory is a subdirectory of /bin, /sbin or /usr/sbin' do
          @original_dest = %w[/bin/file1 /sbin/file2 /usr/sbin/file3]
          @files_to_install = @original_dest.map{|f| File.join @home, 'bin', File.basename(f)}
          config = @original_dest.inject({}){|res, f| res[File.basename(f)] = f; res}
          @gem_dir = make_gem_dir @files_to_install.map{|f| File.basename(f)}, YAML.dump(config), @home
          inst = Outsider::Installer.new @gem_dir
          inst.install_files
          inst.should have_installed @files_to_install
        end
        
        it 'installs the file in the home directory if the installation directory starts with /usr, /usr/local, /etc, /var or /opt' do
          @original_dest = %w[/usr/file1 /usr/local/file2 /etc/file3 /var/file4 /opt/file5]
          @files_to_install = @original_dest.map{|f| File.join @home, File.basename(f)}
          config = @original_dest.inject({}){|res, f| res[File.basename(f)] = f; res}
          @gem_dir = make_gem_dir @files_to_install.map{|f| File.basename(f)}, YAML.dump(config), @home
          inst = Outsider::Installer.new @gem_dir
          inst.install_files
          inst.should have_installed @files_to_install
        end
        
        it 'treats the installation path as if relative to the home directory in all other cases' do
          @original_dest = %w[/xyz/file1 /xyz/local/file2]
          @files_to_install = @original_dest.map{|f| File.join @home, f}
          config = @original_dest.inject({}){|res, f| res[File.basename(f)] = f; res}
          @gem_dir = make_gem_dir @files_to_install.map{|f| File.basename(f)}, YAML.dump(config), @home
          inst = Outsider::Installer.new @gem_dir
          inst.install_files
          inst.should have_installed @files_to_install
        end
        
        it 'does any replacements after having processed the ERB tags' do
          @original_dest = %W[/usr/file1 /usr/share/file2 /xyz/file3 #{File.join @home, 'file4'}]
          @files_to_install = %w[file1 .local/share/file2 xyz/file3 file4].map{|f| File.join @home, f}
          config = {
            'file1' => '<%="/usr/"%>file1',
            'file2' => '<%="/usr/share/"%>file2',
            'file3' => '<%="/x"+"y"+"z"%>/file3',
            'file4' => ['/usr/file4', '<%=ENV["HOME"]%>/file4' ]
            }
          @gem_dir = make_gem_dir @files_to_install.map{|f| File.basename(f)}, YAML.dump(config), @home
          inst = Outsider::Installer.new @gem_dir
          inst.install_files
          inst.should have_installed @files_to_install
        end
        
      end
      
      it 'expands the ~ character to the user\'s home directory after processing the ERB tags' do
        @files_to_install = %w[file1 file2 file3].map{|f| File.join @home, 'test', f}
        config = {
          'file1' => '~/<%="test"%>/file1',
          'file2' => '~/test/file2',
          'file3' => ['/xyz', '~/test/file3']
          }
        @gem_dir = make_gem_dir @files_to_install.map{|f| File.basename(f)}, YAML.dump(config), @home
        inst = Outsider::Installer.new @gem_dir
        inst.install_files
        inst.should have_installed @files_to_install
      end

    end
    
    it 'displays a message for each file being installed' do
      @files_to_install = install_files_list 'file1', 'file2'
      @gem_dir = make_gem_dir @files_to_install
      inst = Outsider::Installer.new @gem_dir
      inst.install_files
      exp = <<-EOS
Installed file1 to #{@files_to_install['file1']}
Installed file2 to #{@files_to_install['file2']}
      EOS
      $stdout.string.should == exp
    end

  end
  
  describe 'when recording installed files' do
    
    def make_fake_gem gem_dir = nil
      @gem_name = random_string+'-0.2.3'
      @gem_dir = gem_dir || tmpfile( @gem_name)
      FileUtils.mkdir @gem_dir
    end
    
    before do
      @record_file = tmpfile random_string
      FileUtils.rm_f @record_file #ensure the file doesn't exist
      ENV["OUTSIDER_RECORD_FILE"] = @record_file
      
      make_fake_gem
      @inst = Outsider::Installer.new @gem_dir
      @files = %w[file1 file2].map{|f| tmpfile f}
      @install_map = make_install_map @files
    end
    
    after do
      FileUtils.rm_f @record_file
      FileUtils.rm_rf @gem_dir
    end

    context 'The file ENV["OUTSIDER_RECORD_FILE"] doesn\'t exist' do
      
      it 'creates the record file file and write a hash of the files sorted by gems and one of the gems sorted by file in YAML format' do
        @inst = Outsider::Installer.new @gem_dir
        @inst.send :record_installed_files, @files.map{|f| [File.basename(f), f]}
        exp = create_record @gem_dir => %w[file1 file2]
        YAML.load(File.read(@record_file)).should == exp
      end
        
    end
    
    context 'The file ENV["OUTSIDER_RECORD_FILE"] already exists' do
      
      context 'and it\'s a valid record file' do
        
        before do
          @previous = create_record '/tmp/gem1-0.0.1' => %w[a b], '/tmp/gem2-2.4.9' => %w[a c]
          File.open(@record_file, 'w'){|f| YAML.dump @previous, f}
        end
        
        context 'and no other gem owns the same files' do
          
          it 'adds entries for the new gem and the new files to the hash' do
            @inst.send :record_installed_files, @install_map
            exp = Marshal.load Marshal.dump(@previous)
            exp.merge!( {'/tmp/file1' => [{:gem => @gem_name, :origin => in_gem('file1')}], '/tmp/file2' => [{:gem => @gem_name, :origin => in_gem('file2')}]})
            YAML.load(File.read(@record_file)).should == exp
          end
          
        end
        
        context 'and other gems own the same files' do
          
          it 'adds the new gem to the existing ones' do
            @files = %w[/tmp/a /tmp/c /tmp/file1]
            @install_map = make_install_map @files
            @inst.send :record_installed_files, @install_map
            exp = Marshal.load Marshal.dump(@previous)
            exp.merge!( { '/tmp/file1' => [{:gem => @gem_name, :origin => in_gem('file1')}]})
            exp['/tmp/a'] << {:gem => @gem_name, :origin => in_gem('a')}
            exp['/tmp/c'] << {:gem => @gem_name, :origin => in_gem('c')}
            YAML.load(File.read(@record_file)).should == exp
          end
          
          it 'doesn\'t add the new gem to the existing ones if it is already recorded, but moves it at the end instead' do
            @previous = create_record @gem_dir => %w[a b], '/tmp/gem2-2.4.9' => %w[a c]
            File.open(@record_file, 'w'){|f| YAML.dump @previous, f}
            @files = %w[/tmp/a /tmp/c /tmp/file1]
            @install_map = make_install_map @files
            @inst.send :record_installed_files, @install_map
            exp = Marshal.load Marshal.dump(@previous)
            exp['/tmp/a'].delete_if{|h| h[:gem] == @gem_name }
            exp['/tmp/a'] << {:gem => @gem_name, :origin => in_gem('a')}
            exp['/tmp/c'] << {:gem => @gem_name, :origin => in_gem('c')}
            exp.merge!( { '/tmp/file1' => [{:gem => @gem_name, :origin => in_gem('file1')}]})
            YAML.load(File.read(@record_file)).should == exp
          end
          
        end
        
        context 'and it isn\'t a valid record file' do
          
          after do
            @to_remove.each{|f| FileUtils.rm_rf f} if defined? @to_remove
          end
          
          def record_file str
            File.open(@record_file, 'w'){|f| f.write str}
          end
          
          before do
            @backup_file = @record_file + '-1'
            @to_remove = [@backup_file]
          end

          
          context 'because it isn\'t a valid YAML file' do

            it 'displays a warning and renames the original file appending a progressive number to it' do
              record_file "by_file: {"
              @inst.should_receive(:warn).once.with("The file #{@record_file} isn't a valid record file and will be moved to #{@backup_file}")
              @inst.send :record_installed_files, @install_map
              exp = create_record @gem_dir => %w[file1 file2]
              YAML.load(File.read(@record_file)).should == exp
              File.should exist(@backup_file)
              File.read(@backup_file).should == 'by_file: {'
            end
            
          end
          
          context 'because it doesn\'t contain the correct objects' do
            
            it 'displays a warning and renames the original file appending a progressive number to it' do
              record_file "a string"
              @inst.should_receive(:warn).once.with("The file #{@record_file} isn't a valid record file and will be moved to #{@backup_file}")
              @inst.send :record_installed_files, @install_map
              exp = create_record @gem_dir => %w[file1 file2]
              YAML.load(File.read(@record_file)).should == exp
              File.should exist(@backup_file)
              File.read(@backup_file).should == 'a string'
            end
            
          end
          
          it 'uses a number which produces a unique filename' do
            @backup_file = @record_file + '-3'
            @to_remove = [@backup_file, @record_file + '-1', @record_file + '-2']
            record_file "by_file: {"
            (1..2).each{|n| `touch #{@record_file}-#{n}`}
            @inst.should_receive(:warn).once.with("The file #{@record_file} isn't a valid record file and will be moved to #{@backup_file}")
            @inst.send :record_installed_files, @install_map
            exp = create_record @gem_dir => %w[file1 file2]
            YAML.load(File.read(@record_file)).should == exp
            File.should exist(@backup_file)
            (1..2).each{|n| File.should exist(@record_file + "-#{n}")}
            File.read(@backup_file).should == 'by_file: {'
          end
          
        end
          
      end
      
    end
    
    context 'when the OUTSIDER_RECORD_FILE environment variable isn\'t set' do
      
      before do
        ENV['OUTSIDER_RECORD_FILE'] = nil
        @default_record_file = '/var/lib/outsider/installed_files'
      end
      
      it 'uses the value stored in the /etc/outsider.conf file, if it exists' do
        @inst = Outsider::Installer.new @gem_dir
        @record_file = tmpfile random_string
        File.should_receive(:exist?).with('/etc/outsider.conf').once.and_return true
        File.should_receive(:read).with('/etc/outsider.conf').once.and_return @record_file
        mock_file_name = tmpfile random_string
        @files_to_install = [mock_file_name]
        File.should_receive(:read).with(@record_file).once.and_return YAML.dump({})
        file = File.open(mock_file_name, 'w')
        File.should_receive(:open).with(@record_file, 'w').once
        File.should_receive(:directory?).with(File.dirname(@record_file)).once.and_return true
        @inst.send :record_installed_files, @install_map
        file.close
      end
    
      it 'uses /var/lib/outsider/installed_files as default record file if the /etc/outsider.conf file doesn\'t exist' do
        File.should_receive(:exist?).with('/etc/outsider.conf').and_return(false)
        @inst = Outsider::Installer.new @gem_dir
        mock_file_name = tmpfile random_string
        @files_to_install = [mock_file_name]
        File.should_receive(:read).with(@default_record_file).once.and_return YAML.dump({})
        file = File.open(mock_file_name, 'w')
        File.should_receive(:open).with(@default_record_file, 'w').once
        File.should_receive(:directory?).with('/var/lib/outsider').once.and_return true
        @inst.send :record_installed_files, @install_map
        file.close
      end
      
      it 'uses /var/lib/outsider/installed_files as default record file if the /etc/outsider.conf file is empty' do

        @inst = Outsider::Installer.new @gem_dir
        mock_file_name = tmpfile random_string
        @files_to_install = [mock_file_name]
        File.should_receive(:read).with(@default_record_file).once.and_return YAML.dump({})
        file = File.open(mock_file_name, 'w')
        File.should_receive(:open).with(@default_record_file, 'w').once
        File.should_receive(:directory?).with('/var/lib/outsider').once.and_return true
        File.should_receive(:exist?).with('/etc/outsider.conf').and_return(true)
        File.should_receive(:read).with('/etc/outsider.conf').once.and_return ''
        @inst.send :record_installed_files, @install_map
        file.close
      end
      
      it 'creates any missing directories in the path ' do
        @inst = Outsider::Installer.new @gem_dir
        mock_file_name = tmpfile random_string
        @files_to_install = [mock_file_name]
        File.should_receive(:directory?).with('/var/lib/outsider').once.and_return false
        FileUtils.should_receive(:mkdir_p).with('/var/lib/outsider').once
        File.should_receive(:read).with(@default_record_file).once.and_return YAML.dump({})
        file = File.open(mock_file_name, 'w')
        File.should_receive(:open).with(@default_record_file, 'w').once
        @inst.send :record_installed_files, @files
        file.close
      end
      
    end
    
    context 'when doing a user install' do
      
      before do
        @home = tmpfile random_string
        ENV['OUTSIDER_RECORD_FILE'] = nil
        ENV['HOME'] = @home
        FileUtils.rm_rf @home
        FileUtils.mkdir @home
        @default_record_file = "#{ENV['HOME']}/.outsider/installed_files"
      end
      
      after do
        FileUtils.rm_rf @home
      end
      
      it 'uses ENV["HOME"]/.outsider/installed_files as record file if the OUTSIDER_RECORD_FILE environment variable is not set' do
        make_fake_gem File.join( @home, random_string + '-1.2.3')
        @inst = Outsider::Installer.new @gem_dir
        mock_file_name = tmpfile random_string
        @files_to_install = [mock_file_name]
        File.should_receive(:read).with(@default_record_file).once.and_return YAML.dump({})
        file = File.open(mock_file_name, 'w')
        File.should_receive(:open).with(@default_record_file, 'w').once
        File.should_receive(:directory?).with(File.dirname(@default_record_file)).once.and_return true
        @inst.send :record_installed_files, @install_map
        file.close
      end
      
      it 'uses ENV["HOME"]/.outsider/installed_files as record file even if the OUTSIDER_RECORD_FILE environment variable is set' do
        ENV['OUTSIDER_RECORD_FILE'] = tmpfile random_string
        make_fake_gem File.join( @home, random_string + '-1.2.3')
        @inst = Outsider::Installer.new @gem_dir
        mock_file_name = tmpfile random_string
        @files_to_install = [mock_file_name]
        File.should_receive(:read).with(@default_record_file).once.and_return YAML.dump({})
        file = File.open(mock_file_name, 'w')
        File.should_receive(:open).with(@default_record_file, 'w').once
        File.should_receive(:directory?).with(File.dirname(@default_record_file)).once.and_return true
        @inst.send :record_installed_files, @install_map
        file.close
      end
      
      it 'doesn\'t attempt to read /etc/outsider.conf' do
        make_fake_gem File.join( @home, random_string + '-1.2.3')
        @inst = Outsider::Installer.new @gem_dir
        mock_file_name = tmpfile random_string
        @files_to_install = [mock_file_name]
        File.should_receive(:exist?).with('/etc/outsider.conf').never
        File.should_receive(:read).with(@default_record_file).once.and_return YAML.dump({})
        file = File.open(mock_file_name, 'w')
        File.should_receive(:open).with(@default_record_file, 'w').once
        File.should_receive(:directory?).with(File.dirname(@default_record_file)).once.and_return true
        @inst.send :record_installed_files, @install_map
        file.close
      end
      
    end
    
  end
  
  describe 'when uninstalling files' do
    
    RSpec::Matchers.define :have_uninstalled do |files|
      match do |inst|
        files = files.values if files.is_a? Hash
        @expected_files = files.dup
        @uninstalled_files = files.select{|f| !File.exist? f}
        @expected_files.size == @found_files.size
      end
      failure_message_for_should do |inst|
        installed_msg = @uninstalled_files.empty? ? "Uninstalled no file" : "only uninstalled #{@uninstalled_files.join ', '}"
        "expected #{inst} to uninstall #{@expected_files.join ', '} but it #{installed_msg}"
      end
    end
    
    def make_fake_gem
      @gem_name = random_string+'-0.2.3'
      @gem_dir = tmpfile @gem_name
      FileUtils.mkdir @gem_dir
    end
    
    def write_record_file arg = nil
      File.open(@record_file, 'w') do |f| 
        if arg.is_a? String then f.write arg
        else f.write create_record(arg || {@gem_dir => @files.map{|f| File.basename(f)}}, true)
        end
      end
    end
    
    def create_files files = nil
      (files || @files).each{|f| `touch #{f}`}
    end
    
    after do
      # We can't use rm_f because this clashes with the expecations set in the
      # examples
      FileUtils.rm @record_file if File.exist? @record_file
      FileUtils.rm_rf @gem_dir
    end
    
    before do
      @record_file = tmpfile random_string
      FileUtils.rm_f @record_file #ensure the file doesn't exist
      ENV["OUTSIDER_RECORD_FILE"] = @record_file
      
      make_fake_gem
      @inst = Outsider::Installer.new @gem_dir
      @files = %w[file1 file2].map{|f| tmpfile f}
      @install_map = make_install_map @files
    end
    
    it 'does nothing if the record file doesn\'t exist' do
      FileUtils.should_receive(:rm_f).never
      @inst.uninstall_files
    end
    
    it 'does nothing if the record file is invalid' do
      write_record_file 'invalid record file contents'
      FileUtils.should_receive(:rm_f).never
      @inst.uninstall_files
      write_record_file 'invalid YAML file: {'
      @inst.uninstall_files
    end
    
    it 'removes all files listed in the record file as belonging to the gem' do
      write_record_file
      @files.each{|f| FileUtils.should_receive(:rm_f).with(f).once}
      @inst.uninstall_files
    end
   
    it 'doesn\'t remove a file if the gem isn\'t the last listed in the record file for it' do
      other_gem = '/tmp/other_gem-1.5.7'
      record = {
        @files[0] => [{:gem => @gem_name, :origin => in_gem(File.basename(@files[0]))}, {:gem => other_gem, :origin => File.join(other_gem, File.basename(@files[0]))}],
        @files[1] => [{:gem => @gem_name, :origin => in_gem(File.basename(@files[1]))}]
      }
      write_record_file YAML.dump(record)
      FileUtils.should_receive(:rm_f).with(@files[0]).never
      FileUtils.should_receive(:rm_f).with(@files[1]).once
      @inst.uninstall_files
    end
    
    it 'removes itself from the record file' do
      other_gem = '/tmp/other_gem-1.5.7'
      record = {
        @files[0] => [{:gem => @gem_name, :origin => in_gem(File.basename(@files[0]))}, {:gem => other_gem, :origin => File.join(other_gem, File.basename(@files[0]))}],
        @files[1] => [{:gem => @gem_name, :origin => in_gem(File.basename(@files[1]))}]
      }
      write_record_file YAML.dump(record)
      FileUtils.should_receive(:rm_f).with(@files[0]).never
      FileUtils.should_receive(:rm_f).with(@files[1]).once
      @inst.uninstall_files
      exp = {
        @files[0] => [{:gem => other_gem, :origin => File.join(other_gem, File.basename(@files[0]))}]
      }
      new_record = YAML.load File.read(@record_file)
      new_record.should == exp
    end
    
    def make_record gems, gem_order
      res = {}
      gems.each_pair do |gem, files|
        gem_name = File.basename gem
        files.each do |f|
          tmp = tmpfile f
          (res[tmp] ||= []) << {:gem => gem_name, :origin => File.join(gem, f)}
        end
      end
      res.each_value do |v|
        v.sort!{|i, j| gem_order.index(i[:gem]) <=> gem_order.index(j[:gem])}
      end
      res
    end
    
    it 'copy the file provided by the previous gem owning it' do
      File.stub(:exist? => true)
      gems = %w[/tmp/gem1-1.5.7 /tmp/gem2-2.4.0 /tmp/gem3-0.2.1]
      gem_names = gems.map{|g| File.basename g}
      @rel_files = @files.map{|f| File.basename f}
      files = {@gem_dir => @rel_files, gems[0] => [@rel_files[0], @rel_files[1]], gems[1] => [@rel_files[1], tmpfile('file3')], gems[2] => [@rel_files[1]]}
      record = make_record( files, [gem_names[0], gem_names[1], @gem_name, gem_names[2]])
      write_record_file YAML.dump(record)
      FileUtils.should_receive(:cp).with(File.join(gems[0], @rel_files[0]), @files[0]).once
      @inst.uninstall_files
    end
    
     it 'skips any non-existing files when copying uninstalled files' do
      @files.delete_at 1
      gems = %w[/tmp/gem1-1.5.7 /tmp/gem2-2.4.0]
      gems.each do |g|
        FileUtils.rm_rf g
        FileUtils.mkdir g
      end
      gem_names = gems.map{|g| File.basename g}
      @rel_files = @files.map{|f| File.basename f}
      files = {@gem_dir => @rel_files, gems[0] => [@rel_files[0]], gems[1] => [@rel_files[0]]}
      files.each_pair do |k, v|
        next if k == @gem_dir
        v.each{|f| `touch #{File.join k, f}`}
      end
      FileUtils.rm File.join(gems[1], @rel_files[0])
      record = make_record( files, [gem_names[0], gem_names[1], @gem_name])
      write_record_file YAML.dump(record)
      @inst.stub(:read_record_file => record)
      FileUtils.should_receive(:cp).with(File.join(gems[1], @rel_files[0]), @files[0]).never
      FileUtils.should_receive(:cp).with(File.join(gems[0], @rel_files[0]), @files[0]).once
      @inst.uninstall_files
     end
    
  end
  
end