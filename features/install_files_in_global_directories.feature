Feature: install files in global directories I have write access to
  In order to have files globally availlable
  As a user
  I want to install files in a directory outside $GEM_HOME I have write access to
  
  Scenario: No global_install_config file exists in the current directory
    Given there's no global_install_config file in the current directory
    When I run the gem command
    Then nothing should be done
  
  Scenario: A global_install_config file exists in the current directory but it's empty
  
  Scenario: The global_install_config file only wants to install files in fixed directories
    Given a global_install_config YAML file containing not containing ERB tags:
      """
      file1.desktop: /tmp/file1.desktop
      file2.desktop: /tmp/file2.desktop
      """
    When I run the gem command
    Then the files should be installed in the given directories
  
  Scenario: The global_install_config file wants to install files in directories determined at runtime
  
  Scenario: The global_install_config file wants to install files in a directory which doesn't exist
  
  Scenario: The global_install_config file wants to install files which don't exist