---
title: "Run-File"
description: "xx"
date: "2017-09-19"
categories:
  - "ruby"
---
'm pretty sure that everyone has at some point experienced this mixed feeling of disbelieve and confusion when 
looking at code that was written weeks/months or years ago realizing that you have no idea what the code was 
meant to do.

We develop and apply a lot of patterns and techniques to prevent this situations from happening but keep on forgetting 
that someone, somewhere sometime has to turn our sourcecode into a working application and deploy it somewhere, or even 
better: continue developing it.

This is typically the point where you realize that there is a lot of knowledge about how to build and deploy your code 
that is only available in the peoples heads or on someones machine who by accident has the right set of versions and 
tools to get everything running.

This post will describe by example some patterns on how to keep this knowledge in your repository next to your code and
furthermore how to ensure that it works in (almost) every environment.

# The Idea
Although it may sound stupid, simple and not worthy a lengthy blog post, the simple idea is to place an 
executable file in the root of each repository whose only responsibility is to call the tools to build, test, package 
and deploy our software. Of course it only sounds simple, as it is also the job of this file to ensure we have the 
right tools in the right versions, the environment is setup accordingly without requiring any interaction from the 
user because we also want to use the script in our shiny CI environment. Those requirements, restrictions and other 
caveats will be discussed in this post.
 
# The Example
The example project that I will use to demonstrate the key points of a run file is the simple and well known TodoMVC 
application. 
The backend is implemented in Java using Spring Boot and the web frontend is created with Vue.js and a command line
client in Ruby is also provided to add some programming language diversity.
For easier distribution we will produce a Docker image of our application and provide Terraform based code that deploys
our application into AWS.

# The Run file
To give the whole thing a name we call this magic script the run-file from now on. I've seen it named go/start/build and 
various other names in the wild, just be sure to use only one name across all your repositories.
The following paragraphs line out some of the key aspects of a run file, the full source is available on the [example 
Github project](https://github.com/pellepelster/run-file).

## Choice of scripting language
When it comes to the choice of language to use for your run scripts you should keep the following constraints in mind:

* To set the entry barrier for the usage of the run file as low as feasible it should be possible to run the file as it is
 without requiring any prerequisites on the executing system apart from the interpreter mentioned in the hashbang 
(e.g. `#!/usr/bin/env ruby` or just plain bash `#!/usr/bin/env bash`). 
* Bash is maybe the lowest common denominator for all platforms (nowadays even Windows) so this would be a solid choice
for the first version

For our example though I will implement the run file in Ruby for the following reasons:
* For a developer that is profound in Java and Javascript (like in our example) or in any other language scripting 
languages like Ruby or Python are a more natural choice than Bash because they are easier to read, understand and adopt 
than Bash scripts
* For more complex tasks bash script tend to get a little bit convoluted
* Ruby comes with many very good libs for tasks that we typically need to do in our run files
* A ruby interpreter is available on most of the major platforms

## Make it runnable
If you chose to go with Ruby like in our example there is a little problem to solve: We have to make our script directly 
runnable, which is no problem for Ruby when using the already mentioned hashbang `#!/usr/bin/env ruby`. The problem lies
in the gem dependencies we want to fetch and use without requiring the user to call [bundler](http://bundler.io/) first.
The solution is the code below that executes bundler every time the `vendor` directory where our gems are installed
and the accompanying `Gemfile` get out of sync. The final `Bundler.require` ensures all gems mentioned in the `Gemfile`
are available in our Ruby runtime environment.
```
#!/usr/bin/env ruby

require 'fileutils'
unless FileUtils.uptodate? 'vendor', %w[Gemfile]
  system('bundle install --path=vendor/bundle') ||
      raise('bundle install failed')
  system('touch vendor')
end

require 'bundler'
Bundler.require
```

## Tasks
Before we deep dive into the implementation of the run-file lets take a step back and look and the typical 
responsibilities of a run-file. Apart from some specialized tasks that serve some project specific usecases
there is a common set of tasks that needs to be performed on many software projects:

### build
Pretty obvious this task compiles all source into something executable or usable. Note this must not only 
include turning Java sources into Jars or C++ files into executables. This step should produce all the 
artifacts that represent the deliverables of the project, e.g. docker images, documentation and so on.
Of course we won't ship a single line of code that is not tested, so we also execute the unit tests for our 
code to ensure everything works as expected.

### test
As our software is made up of several different components this task executes the integration/functional 
tests that safeguard that all our components are working together nicely. As those functional tests tend to 
run much longer than the unit tests that are already executed after each build, they get an extra task.

### lint
This tasks ensure basic project hygiene executing all the linters for all the sourcecode contained in the 
repository. It is noteworthy that this task should also be part of the main build task and break the build
if a linter fails to ensure the code always state in good shape.

### format
An accompanying task to the linter task, if available this task should format your sources so that it
matches your linter rules. Together with the linter task this task helps to enforce a common style across
all your sources and helps which is a crucial point when you share a codebase with other developers and 
reinforces collective code ownership.

### run
If your software contains something that is directly executable and usable this would be the task to start 
an instance of your application and point the user in the direction of how to use it. For a web 
application this could be as easy as printing the url where your application can be reached on the command
line.

### deploy
Finally the task to deploy our application to its final destination, this could be a local application server,
a new EC2 instance in the AWS cloud or everything else.

## CLI Structure

### Single Repository Layout
The user of our run-file needs a way to call this tasks and maybe parametrize them on the command line.
For this purpose a command line parser that supports git style subcommands would be a good choice
because this enables us to structure the tasks of our run-file around our projects components without
 ending up with a big unmaintainable pile of tasks in a 1000+ lines run file.
In the ruby world the [GLI](https://github.com/davetron5000/gli) gem is a good choice supporting 
sub-commands and even supporting [Bash completion](https://github.com/davetron5000/gli/wiki/ShellCompletion)
 to some degree.
We will break down our run-file into an entry point in the root of the repository. This will be the file that
gets executed. The different components of our project `todo-server`, `todo-frontend`, `todo-deploy` and `todo-cli` all 
contain a `run_commands.rb` file that contribute all the tasks available for a specific component. Those 
file get included by the main run-file which itself will only delegate to the appropriate task of 
a specific component.

``` 
run-file-example/
├── todo-cli/
│   ├── [...]
│   └── run_commands.rb
├── todo-deploy/
│   ├── [...]
│   └── run_commands.rb
├── todo-frontend/
│   ├── [...]
│   └── run_commands.rb
├── todo-server/
│   ├── [...]
│   └── run_commands.rb
├── config.yaml
└── run
```

### Multi-Repository Layout
If you decide to distribute your projects component among multiple repositories then there is of course no 
need to break down your run file, in that case you can keep everything in the root run-file.

## Documentation
I know documentation is everyone's favourite part around development and can spark a lot of heated discussions.
In our scope documentation means we have to give the user of our run-file a clue what our run-file is capable of 
and what parameters are available for each task.
From my experience even when the documentation is as close as in the `README.md` next to the run-file it tends
to get outdated pretty fast.
As an alternative like many command line parsing libraries `GLI` supports to directly add documentation for 
all parameters, flags and commands it adds to the run-file.
Have a look at the basic GLI definitions below:

```
require './todo-cli/run_commands.rb'
require './todo-server/run_commands.rb'
require './todo-deploy/run_commands.rb'
require './todo-frontend/run_commands.rb'

version '0.0.1'
program_desc 'run file for an example todo webservice'
subcommand_option_handling :normal

# global options
desc 'enable verbose logging for run-file'
default_value false
switch %i[verbose]

desc 'build front- and backend'
command :build do |build|
  build.action do |global_options, _options, _args|
    frontend_build(global_options[:verbose])
    server_build(global_options[:verbose])
    docker_build(global_options, __dir__)
  end
end

desc 'run the application locally'
command :run do |run|
    [...]
end

desc 'lint front- and backend'
command :lint do |lint|
    [...]
end
```

If you call the run-file now without any parameters or commands it shows a nicely formatted
help page:

```
$ ./run --help
NAME
    run - run file for an example todo webservice

SYNOPSIS
    run [global options] command [command options] [arguments...]

VERSION
    0.0.1

GLOBAL OPTIONS
    --help         - Show this message
    --[no-]verbose - enable verbose logging for run-file
    --version      - Display the program version

COMMANDS
    build    - build front- and backend
    cli      - cli tasks
    deploy   - deploy tasks
    docker   - docker tasks
    frontend - frontend tasks
    help     - Shows a list of commands or help for one command
    lint     - lint front- and backend
    run      - run the application locally
    server   - server tasks
```

If you keep the documentation that close to your actual tasks it minimizes the hassle to keep it 
up to date and therefore maximizes the possibility that someone will actually do it.


## Executing Commands
When using languages like Ruby we have to stop a minute and think about how we want to execute shell
commands because we need to call them a lot.
For Ruby there are a thousand ways to execute commands on the shell (or at least so many that someone
found it necessary to create a [flow chart](https://i.stack.imgur.com/1Vuvp.png) when to use which way.
To make things a little bit easier we will use the `childprocess` gem which hides all the gritty 
details of handling command lines across different operating systems and Ruby implementations and gives
us a clean interface to work with.
I created a small wrapper methods for the most common tasks to make it easier to use `childprocess` in 
the context of a run-file. For the detailed implementation details have a look at [execute.rb](https://github.com/pellepelster/run-file/blob/master/lib/execute.rb).

```
# just execute a shell command
def execute(command, verbose: false,
            working_dir: __dir__,
            environment_variables: {},
            show_stdout: true)
  print_debug_header("executing command '#{command.join(' ')}' in directory '#{working_dir}'", verbose)
  process = ChildProcess.build(*command)
  process.cwd = working_dir
  inject_environment(process, environment_variables)
  process.io.inherit! if show_stdout

  process.start
  process.wait
  print_debug_footer verbose
  process.exit_code
end

# execute a shell command, capture and return all output (stderr & stdout)
def execute_and_capture(command, working_dir: __dir__, environment: {}, verbose: false)
  [...]

  [process.exit_code, output]
end

# execute a command and fail directly if the command itself fails
def execute_or_fail(command, verbose)
  [...]
end

```

## Debugging and Logging
No matter how hard we try, sooner or later our run scripts will fail. In that case it is important 
to provide debug and logging facilities to make it easier to pin down the actual error.
For Bash based scripts it is rather easy, just enable xtrace (`bash -x`) and bash will spit out 
all details for every command it runs.
For our Ruby based run file we will introduce a global command line option `--verbose` that we 
pass through all tasks.

```
# global options
desc 'enable verbose logging for run-file'
default_value false
switch %i[verbose]

command :server do |server|
  server.desc 'build the server'
  server.command :build do |build|
    build.action do |global_options, _options, _args|
      server_build(global_options[:verbose])
    end
  end
end

def server_build(verbose)
  puts 'starting server build' if verbose
  [...]
end
```

It is also a good habit to invest some time into correct error handling and
meaningful error messages for the user. Try not to fail with a generic
*Ooops something went wrong* error, but try to be as precise as possible:

## Prepare the environment
Before we can start a single task like for example running a Gradle build or applying a Terraform
file we have to setup the environment accordingly for the tools.

### Check Tools and Versions
The first step of environment setup is to check for the availability of the needed tools. For example 
to check if a Java compiler is installed or whether Terraform is available to spin up our infrastructure.
The ideal approach here is to depend as less on the local machine as possible. Don't expect any tools
to be there or if they are to be in the right version.
We will try to setup the needed environment by ourself if feasible, minimizing the dependencies
on the local machine setup. Of course we will not start to modify the system we are executed on by 
installing system wide packages or binaries in the users home folder.
If possible we will install the tools locally in the projects folder to avoid interfering with the 
users system.
The correct approach here depends on the specific needed tools, read on for two examples: 

#### Checking for tools and version (Java))
Although we could download Java in the right version and use it locally for our project, here for the 
sake of the example we rely on the users system to provide a JDK and just check if the right executables 
are available on the path and check their versions:

```
# ensure command is present and in the right version
def ensure_command_with_version(command, wanted_version,
                                version_argument: '--version',
                                version_regex: '.*[v](\d+.\d+.\d+).*', verbose: false)
  raise "command '#{command}' not found" unless available_in_path?(command)
  _, stdout = execute_and_capture([command, version_argument], verbose: verbose)

  version_matches, installed_version = version_matches(stdout, version_regex, wanted_version)
  raise "wanted version (#{wanted_version}) of command #{command} not found, found #{installed_version} instead" \
    unless version_matches
end

ensure_command_with_version('java', '0.10.2',
                            version_argument: '-version',
                            version_regex: '.*(\d+.\d+.\d+)_.*',
                            verbose: verbose)

```

As the retrieval of version number is pretty uniform along many command line utilities I created
a helper method that we can reuse later when we have to check some other tools.

When it comes to version check, especially for tools that are in their early phase of life we often 
see frequent releases, leading to steadily increasing version numbers. Pay some attention to the actual
version you check and ask yourself: What features from the tool in question do I really need? Often enough
it is perfectly ok to just check for major and minor versions and leave the patch version aside. Also try
not to enforce a specific release but try for aim for 'at least version x.y.z.'. as not everyone is on a
distribution or operating system that always running updating to the latest versions

Important for this approach is, that in case the correct version could not be found to provide some 
hints what exactly is missing and how to install it on the system. This may be obvious for Java, but 
there may be tools that need special repositories, brew packages or any other unexpected dependencies.

#### Install Tools Locally (Terraform)
As Terraform is written in Go and like any other Go program comes with its own runtime and is statical linked 
it should run without any dependencies on all platforms. So we go ahead and just download the appropriate version 
for our platform and architecture:

```
def ensure_terraform(version, checksum, verbose)
  executable = "terraform"
  file = download_and_extract(
     "https://releases.hashicorp.com/terraform/#{version}/terraform_#{version}_linux_amd64.zip",
      checksum,
      executable,
      verbose
  )
  file
end

ensure_terraform('0.10.6', 'fbb4c37d91ee34aff5464df509367ab71a90272b7fab0fbd1893b367341d6e23')
```

Notably here is that when downloading software from the internet you should always check the checksum (hence the name)
to ensure you really got what you expected.

### Environment Variables and Parameters
If your tasks depends on environment variables or other parameters, check if they are provided and if not and 
feasible provide meaningful and safe defaults.
The approach here is to minimize the need for mandatory parameters so anyone can start using the run-file
right away without having to guess needed parameters first.
For example a build number is only available in a CI environment but we can provide a value to enable local builds:

Also if variables are taken from environment or defaults are used it can be helpful to dump the actual configuration
before running a task so the user has a chance to see what the current runtime configuration looks like.

Quite obvious but worth mentioning is when assuming defaults is that we should use the least destructive and safe code
path as our default. Imagine someone calling the deploy task and we start tearing down the infrastructure in order
to deploy a new one, or deploying a development version of a software to a public repository. Safeguard these actions
with explicit switches with names that clearly communicate the what is happening respectively where it is happening.

```
./run deploy --env production 
```

### Configuration
There are aspects in the run file, that tend to change, like for example version numbers and checksums of used tools,
paths where to find tools and so on.
If these aspects change more than two times it may be good idea to extract those in a simple configuration file. In an
extended version you could also think about introducing a machine and/or user specific configuration file to cope with
edge cases on different machines.

```
---
project:
   name: todo
npm:
    version:   v6.11.2
    checksum:  d8e209417b6e69d2c77d662c59d5b082da6d2290c846ca89af9c1239bb7c3626
terraform:
    version:   0.10.6
    checksum:  d8e209417b6e69d2c77d662c59d5b082da6d2290c846ca89af9c1239bb7c3626

```

```
class RunConfig < RunConfigWrapper
  def initialize
    @config = load_global_config.merge(load_user_config)
  end

  private

  def load_config(config_filename)
    config = {}
    config = YAML.load_file(config_filename) if File.exist?(config_filename)
    config
  end

  def load_global_config
    load_config 'run-config.yaml'
  end

  def load_user_config
    load_config "run-config_#{Etc.getlogin}.yaml"
  end
end

[...]

CONFIG = RunConfig.new

[...]

ensure_terraform(CONFIG['terraform']['version'], CONFIG['terraform']['checksum'], verbose)


```

### Secrets
Certain tasks need access to secrets like for example the Terraform run that needs to know the AWS credentials.
To avoid scattering our AWS api access keys unencrypted in our repository and risking to loose them, we store them 
in a encrypted separate repository using the [pass](https://www.passwordstore.org/) password-manger to store 
and retrieve them.

```
# read a secret from the pass password manager
def pass(path, verbose = false)
  puts "reading pass secret '#{path}'"
  exit_code, secret = execute_and_capture(['pass', path], verbose: verbose)
  raise "reading pass secret '#{path}' failed" if exit_code > 0
  secret
end

aws_access_key_id = pass('aws/pelle/playground/admin/access-key-id')
aws_secret_access_key = pass('aws/pelle/playground/admin/secret-access-key')
```

## Closing words
The laid out project is of course very artificial and overly complected example with the intention to demonstrate 
all major aspects of an run-file. When writing a real run file don't get carried away, and always remind yourself: 
It should just prepare the environment and start other tools. If you catch yourself writing functionality apart 
from that you should step back and look for a better tool to do the job or extract the needed functionality into 
a separate tool. In our example the command to add a new todo entry from the command line is completely out of 
scope of a run-file and extracted into a separate program. Of course we provide a task to execute said program 
as this is our core competence.
Also (in contrast to this example) start simple. Start with a minimal bash file and find out what your really need
before creating abstractions. After the second or third run-file when you see patterns emerge you can start to
move the duplicate code elsewhere.

