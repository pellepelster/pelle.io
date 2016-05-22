---
title: "Testing your infrastructure code"
description: "How to test Ansible roles (and any other piece of infrastrcture code)"
date: "2016-06-01"
draft: true
categories:
  - "ansible"
---

A while ago I wrote an Ansible role for deploying Spring Boot applications to an Ubuntu 14.x system. The role was put into action, time passed and when I needed the role again, Ubuntu 16.x was en vogue and (of course) the role failed on the 16.x system. To prevent this from happening again in the future, and because I want to make that role publicly available, I somehow had to ensure that the role works reliably on all the major distributions. The tool I picked for this task is KitchenCI, read on for a quick walkthrough on how to do continuous infrastructure integration using Kitchen CI and ServerSpec.

First of all a quick overview of what KitchenCI is:

From https://kitchen.ci

> Test Kitchen is a test harness tool to execute your configured code on one or more platforms in isolation.

KitchenCI provides you with a wide range of drivers (Vagrant, AWS, Openstack, ...) to spin up virtual instances that are provisioned with Ansible, Chef, Puppet or whatever flavor of configuration management you like. In our case we will use the Ansible provisioner to execute the role that is under test.
Kitchen can be instructed to execute tests for any combination of platform and testsuite that we supply. After each successful run, ServerSpec tests ensure that everything worked like expected.

# Setup Kitchen

KitchenCI originates in the Chef universe and therefore is written in Ruby, so first thing to do is to create a `Gemfile` that declares all the dependencies we need to run Kitchen.

```
source 'https://rubygems.org'

gem 'test-kitchen'
gem 'kitchen-vagrant'
gem 'serverspec'
gem 'kitchen-ansible'
gem 'busser-serverspec'
```

To setup the needed Ruby environment with its dependencies we will be using bundler.

```
gem install bundler
bundle install --path vendor/bundle
```

# Configure KitchenCI

Now that the environment is complete lets have a look at the KitchenCI configuration file `.kitchenfile.yml` itself.

**.kitchenfile.yml**
```
---
driver:
  name: vagrant
  synced_folders:
    - [ "../example-application", "/opt/example-application", "create: true", "type: nfs"]

provisioner:
  name: shell
  name: ansible_playbook
  playbook: playbook_default.yml
  roles_path: ../springboot-role/
  hosts: all
  require_ansible_repo: false
  require_ansible_omnibus: true
  ansible_verbose: true
  ansible_diff: true
  ansible_extra_flags: <%= ENV['ANSIBLE_EXTRA_FLAGS'] %>

platforms:
- name: ubuntu-14.04
- name: ubuntu-16.04
  provisioner:
    require_ansible_repo: true
    require_ansible_omnibus: false

suites:
- name: default
- name: ansible_20
  provisioner:
    ansible_version: 2.0
  excludes:
    - ubuntu-16.04
- name: port_9090
  provisioner:
    playbook: playbook_port_9090.yml

```


The file format is YAML based, the first section `driver` defines what backend to use for the virtual appliances. We are using Vagrant for our local tests, to get an exhaustive list of all available providers call `bundle exec kitchen discover`:

```
$ bundle exec kitchen driver discover
    Gem Name                          Latest Stable Release
    jackal-kitchen-slack              0.1.2
    kitchen-all                       0.2.0
    kitchen-ansible                   0.42.3
    kitchen-ansiblepush               0.3.11
    kitchen-appbundle-updater         0.1.2
    kitchen-azure                     0.1.0
    kitchen-azurerm                   0.3.6
    kitchen-binding                   0.2.2
    [...]
```


Each driver provides a different set of configuration options ([Documentation](https://github.com/test-kitchen/kitchen-vagrant/) for the Vagrant driver), in this case we define `synced_folders` that directly translate into an host to guest folder-mapping in the generated `Vagrantfile`. The mapping is used to inject the Spring Boot application artifacts that the role should deploy. This is necessary because Ansible runs completly inside the machine and thus can only access files that are also in the VM.

The next step is to specify how to provision our virtual machine that is started by Vagrant. As we are testing an Ansible role we will of course be using the Ansible provisioner. The test will be run on a broad variety of distributions, so the installation process for Ansible differs from distribution to distribution. To avoid problems we use [Chef Omnibus](https://github.com/chef/omnibus) to install Ansible. This is configured by setting `require_ansible_repo` to `false` to avoid installation from distribution-native repositories, and `require_ansible_omnibus` to `true` to let Omnibus do its work.
` ansible_verbose` and `ansible_diff` increase the verbosity of the Ansible run and ease the debugging process in case something fails during the provisioning. Finally the folder specified by `roles_path` in injected into the Ansible installation inside the virtual machine and the playbook given by the parameter `playbook` is started.
The playbook in this case is a simple wrapper that just calls the role that we already configured by `roles_path`.

**playbook_default.yml**
```
- name: wrapper for role testing
  hosts: localhost
  roles:
    - { role: springboot-role, spring_boot_file_source_local: '/opt/example-application/build/libs/example-application.jar' }
```

The tested platforms are listed under `platforms`, to see which platforms are available, have a look at the documentation of the driver your are using. As you can see the `ubuntu-16.04` platform has a little bit of extra configuration. Because the Omnibus install does not work (yet) with Ubuntu 16.04 we override the provisioner properties for this platform to use the native platform packages to install Ansible.

Last configuration step is the list of suites we want to test. Again here we can parametrize the provisioner/driver and platform to create new test combinations. In our example we define two suites that run different versions of Ansible and another one that executes the role with a different role configuration by overwriting the `playbook` parameter.
Also note that by using the `excludes` configuration you can stop KitchenCI from running suites for particular platforms. In this case we omit Ununtu 16.04 because there we are installing Ansible form the native package wer we have no direct influence on the exact version, so the test for a specific version would be useless.

# Writing the tests

The testframework we use is ServerSpec (we could have chosen any other framework like rspec, bats, cucumber, ...), they can be plugged in using an plugin system provided by Busser. To see what frameworks Busser supports follow this [link](https://rubygems.org/search?utf8=%E2%9C%93&amp;query=busser-). Kitchen expects the testcases inside the test folder under `test/integration/$suite_name/$test_framework_name/` so as we are using ServerSpec for the `default` suite the tests found under `test/integration/default/serverspec/` are executed, for the `port_9090` suite the tests under `test/integration/port_9090/serverspec/` and so on.

Our (quite minimal) test connects to to the Spring Boot application and checks for the content of the served index page:

**default/serverspec/springboot_example_application_spec**
```
require 'spec_helper'

describe "spring boot example appplication" do
  let(:host) { URI.parse('http://localhost:8080') }

  it "Greetings from Spring Boot" do
    connection = Faraday.new host
    page = connection.get('/').body
    expect(page).to match /Greetings from Spring Boot/
  end

end
```


vice versa the ServerSpec test for the testsuite that deploys the application on port 9090:

**default/serverspec/springboot_example_application_spec**
```
require 'spec_helper'

describe "spring boot example appplication" do
  let(:host) { URI.parse('http://localhost:9090') }

  [...]

end
```


# Run the tests

Before actually running the test lets take a short dive into the Kitchen test-lifecycle, which is made up of five steps:

| step | description |
|------|------|
| create | starts the virtual machine using the configured driver |
| converge | apply the provisioner to the started machines |
| setup | prepare automated tests |
| verify | run the automated test |
| destroy | finally destroy the machine |

Each phase has a corresponding command in the Kitchen client. The `test` command executes all phases in order and removes the machines after a sucessful test.
When not explicitly specified all commands are run for every plaform/testsuite combination. To show a list of alle that would be run use the `list` command:

```
$ bundle exec kitchen list

Instance                Driver   Provisioner      Verifier  Transport  Last Action
default-ubuntu-1404     Vagrant  AnsiblePlaybook  Busser    Ssh        <Not Created>
default-ubuntu-1604     Vagrant  AnsiblePlaybook  Busser    Ssh        <Not Created>
ansible-20-ubuntu-1404  Vagrant  AnsiblePlaybook  Busser    Ssh        <Not Created>
port-9090-ubuntu-1404   Vagrant  AnsiblePlaybook  Busser    Ssh        <Not Created>
port-9090-ubuntu-1604   Vagrant  AnsiblePlaybook  Busser    Ssh        <Not Created>
```

as you can see, not test hast been run yet, so to run all tests for all platform/testsuite combinations call

```
$ bundle exec kitchen test
```

which will run the `default`, the `ansible-2.0` and the `port-9090`  test suite on both platforms (Ubuntu 14.04 and 16.04). To run a test only for a specific combination call:

```
$ bundle exec kitchen test port-9090-ubuntu-1604
```

If a step fails you can always manually invoke the failed phase. So if for example our role fails due to an error after fixing the error we just call

```
$ bundle exec kitchen converge port-9090-ubuntu-1604
$ bundle exec kitchen verify port-9090-ubuntu-1604
```

which again provisions and runs the test against the (hopefully) fixed role. But sometimes the logging output is not enough to determine the root cause of a feiled test, so to debug such cases you can always login into the problematic machine using the `login` command:

```
bundle exec kitchen login port-9090-ubuntu-1604
```

After fixing all the bugs and running the final `test` for all platforms, the `list` returns a heartwarming list of green tests:

```
$ bundle exec kitchen list

Instance                Driver   Provisioner      Verifier  Transport  Last Action
default-ubuntu-1404     Vagrant  AnsiblePlaybook  Busser    Ssh        Verified
default-ubuntu-1604     Vagrant  AnsiblePlaybook  Busser    Ssh        Verified
ansible-20-ubuntu-1404  Vagrant  AnsiblePlaybook  Busser    Ssh        Verified
port-9090-ubuntu-1404   Vagrant  AnsiblePlaybook  Busser    Ssh        Verified
port-9090-ubuntu-1604   Vagrant  AnsiblePlaybook  Busser    Ssh        Verified
```

# Conclusion

After some inital time for initial machine creation and setup the `converge & verify` -> *bug fixing* -> `converge & verify` -> *bug fixing* -> [...] cycle enables you to ensure that your code runs on all platforms you deemed as important. A complete test runs takes some time, mostly due to long converge and setup runs, but the ability to incrementaly try out code changes without the need to recreate the machine greatly reduces the time needed for finding and fixing fixing bugs. I found several bugs within my role right from the start while evaluating KitchenCI. In the long run KitchenCI catched several very subtle errors, mostly accounted to software updates wihtin the distributions that introduced new package versions with new command line arguments, relocated configuration files and in on case a new version of a software that behaved slightly different than the role ecpected. 

This underlines the need not only to test the code for the software your write but also the code that defines your infrastructure.
