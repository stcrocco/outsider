Feature: install files in global directories I have write access to
  In order to have files globally availlable
  As a user
  I want to install files in a directory outside $GEM_HOME I have write access to

  Scenario: No outsider_files file exists in the current directory
    Given there's no outsider_files file in the current directory
    When I run the gem command
    Then nothing should be done
  
  Scenario: A outsider_files file exists in the current directory but it's empty
    Given an empty outsider_files file
    When I run the gem command
    Then nothing should be done
  
  Scenario: The outsider_files file only wants to install files in fixed directories
    Given a outsider_files YAML file not containing ERB tags:
      """
      file1.desktop: /tmp/file1.desktop
      file2.desktop: /tmp/file2.desktop
      """
    When I run the gem command
    Then the files should be installed in the given directories
  
  Scenario: The outsider_files file wants to install files in directories determined at runtime
    Given a outsider_files YAML file containing ERB tags:
      """
      file1: <%= require 'tempfile';File.join Dir.tmpdir, 'file1' %>
      file2: /tmp/file2
      """
    When I run the gem command
    Then the files should be installed in directories obtained evaluating the ERB tags
  
  Scenario: The outsider_files file wants to install files which don't exist
    Given a outsider_files YAML file with:
      """
      file1: /tmp/file1
      file2: /tmp/file2
      """
    And that file1 doesn't exist in the gem directory
    When I run the gem command
    Then only the existing files should be installed
    
  Scenario: The outsider_files file wants to install files in a directory which doesn't exist
    Given a outsider_files YAML file containing nonexisting directories:
      """
      file1: /tmp/outsider_testdir1/subdir/file1
      file2: /tmp/file2
      """
    When I run the gem command
    Then the needed directories should be created with default permissions
    
  Scenario: The outsider_files file wants to install files in a directory which doesn't exist specifying permissions for the path
    Given a outsider_files YAML file containing nonexisting directories:
      """
      file1: /tmp/outsider_testdir1/subdir/file1
      file2: /tmp/file2
      """
    When I run the gem command
    Then the needed directories should be created with default permissions