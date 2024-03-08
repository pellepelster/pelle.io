---
title: "The do file"
subtitle: Developer Experience
date: 2024-02-29T12:00:00+01:00
draft: false
aliases:
  - project-developer-experience-do-file
tags: [ "dx" ]
---

> This post is a part of my series about project developer experience, for the other posts have a look
> [here](/tags/dx/). A fully functional example with all snippets from this post that can be used as a template is
> available [here](https://github.com/pellepelster/solidblocks/blob/main/solidblocks-do/single-project-bash/do), more
> ready to use functions for writing do files are part of my open source project
> [Solidblocks](https://github.com/pellepelster/solidblocks).

Imagine you join a new project and are given your first task to fix a longstanding bug. One of the first questions when
cloning the affected repository often is:

> How do I build this thing?

immediately followed by

> ...and how do I run this thing?

or, in the worst case if the repository content is already deployed somewhere, and you need to re-deploy it:

> ...how do I deploy and operate this thing?

There may be a `README.MD` somewhere with information about some commands that you can run to achieve those goals, 
but this information tends to get outdated very fast. Looking at the state-of-the-art approach towards deploying 
infrastructure, which is pouring all the information needed to create it in code, we can try to apply the same 
pattern to all the glue code that is required to work with the repository.

This rather abstract idea can be realized as a simple script that serves as an entrypoint for all tasks that are 
needed to work with the content and the structure of a repository. You can name it any way you want, I like to call 
them `do` or `go` as the name implies that something can be done here - comparable to the interface of older 
point-and-click adventure games.

You may want to make this consistent across all your repositories so people that are familiar with this concept know 
were to start right away. 

Before we dive into the structure of this `do` script, we have to make difficult decision which language to 
use to implement it. We may be confronted with a wide range of development environments that 
vary both in architecture (AMD64, ARM64, ...) and operating systems (Linux, Windows, OSX, ...). We need 
to make sure to support most of them or at least the ones that are relevant to our situation.

Since the introduction of the Linux subsystem for Windows, the bash shell is a reasonable choice as a scripting 
language that works across all major operating systems.

Unfortunately bash scripts tend to quickly evolve into an unmaintainable mess of `sed`, `awk`, and really awkward regular 
expressions, so another good contender could be Python which also has a solid support across all major 
operating systems. 

Whatever you choose, the purpose of the `do` file is to put all steps needed to interact with the project in to code.
Ideally this code can also be used in a CI/CD environment, so we keep the way the repository is handled in the CI, close
to the local machine, making it easier to debug potential problems in the CI.

The following guide tries to give an abstract overview of what such a `do` file might look like, providing examples for
bash and Python where appropriate.

## Bootstrapping

The first issue we might encounter is how to make the `do` file executable, so it can be run anywhere.

{{< tabs groupId="bootstrapping">}}
{{% tab name="Bash" %}}

For bash we can safely get away with just setting some flags that make our `do` file robust against errors like unset
variables, and force an early return in case of errors. See [bash cheat sheets](https://bertvv.github.io/cheat-sheets/Bash.html) for more tips on how to write safe 
and robust bash scripts.

```Bash
#!/usr/bin/env bash

# exit early if any command fails instead of running the rest of the script
set -o errexit

# fail the script when accessing an unset variable
set -o nounset

# also ensure early fail fore piped commands
set -o pipefail

# enable setting trace mode via the TRACE environment variable
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi
```

{{% /tab %}}
{{% tab name="Python" %}}

For Python the bootstrapping is a little bit more advanced. Although we could just run a `do.py` file written in Python
using the [Python shebang](https://realpython.com/python-shebang/) this would raise several issues. To begin with we might need some Python packages 
(PIPs) for our `do` file that need to be to fetched first. Next we most likely don't want to use the system's 
Python installation for this, as this would create endless possibilities for conflicts with system-wide packages. 
We will use [Python venv](https://docs.python.org/3/library/venv.html) to create a dedicated Python environment for our `do.py` 
file and provide a bash based starter, that bootstraps and executes the created `venv` environment.

```bash
#!/usr/bin/env bash

#[...]

DIR="$(cd "$(dirname "$0")" ; pwd -P)"
VENV_DIR="${DIR}/venv"

function task_bootstrap {
  python3 -m venv "${VENV_DIR}"
  "${VENV_DIR}/bin/pip" install -r "${DIR}/requirements.txt"
}

function task_run {
  "${VENV_DIR}/bin/python" "${DIR}/do.py" $@
}

function task_usage {
  echo "Usage: $0

  bootstrap         initialize the local development environment
  "
  exit 1
}

ARG=${1:-}
shift || true

case ${ARG} in
  bootstrap) task_bootstrap;;
  *) task_run $@ ;;
esac
```

{{% /tab %}}
{{< /tabs >}}

## Structure

To keep the `do` file maintainable it is important to structure the code in a way that makes it easy to read and extend.
Having common patterns here helps you navigate and find your way around multiple `do` files in case you have more than one
repository. 

{{< tabs groupId="structure">}}
{{% tab name="Bash" %}}

This is especially important for Bash because it is lacking a lot of functionality from more mature scripting
languages that we could use to organize the code. To add at least some minimal structure to the `do` file, splitting 
the functionality into simple Bash functions is a good way to ensure that the file does not deteriorate into a thousand 
lines of spaghetti code. A good pattern is to name the functions that are called from the outside `task_${name}`, making
it easy to identify the entry points that are called from the outside.

```Bash
function task_build {
  echo "building the project..."
}

function task_test {
  echo "running the integration tests..."
}
```

Those functions then get dispatched by a case-switch at the end of the file:

```shell
ARG=${1:-}
shift || true

case ${ARG} in
  build) task_build $@ ;;
  deploy) task_deploy $@ ;;
    
  [...]
esac
```

making them easily callable from the shell, for example:

```shell
$ ./do build
building the project...
```

{{% /tab %}}
{{% tab name="Python" %}}

To achieve this in Python we can make use of a command line libraries, e.g. [click](https://click.palletsprojects.com/en/8.1.x/) which lets us not 
only define different commands to run, but also a way to describe and verify arguments for those commands.

```python
import click


@click.group()
def cli():
    pass


@click.command()
def build(build_type):
    """build the project"""
    click.echo(f"building the project...")


@click.command()
def test(parallel):
    """run integration tests"""
    click.echo(f"running the integration tests...")


cli.add_command(build)
cli.add_command(test)

if __name__ == '__main__':
    cli()
```

After the previously explained bootstrap step via the `do` file, the commands defined with click are directly callable from the shell:

```shell
./do bootstrap
./do          
Usage: do.py [OPTIONS] COMMAND [ARGS]...

Options:
  --help  Show this message and exit.

Commands:
  build  build the project
  test   run integration tests

```
{{% /tab %}}
{{< /tabs >}}


## Execution Context

Ideally the tasks from the `do` file can also be used a CI/CD system. Keeping that in mind we should never assume that 
the working directory is always correctly set. Always provide the full path when referencing files.

{{< tabs groupId="context">}}
{{% tab name="Bash" %}}

In the shell we can use the convenient `DIR` variable introduced in the file header to reference files needed 
by the `do` file.

```shell
DIR="$(cd "$(dirname "$0")" ; pwd -P)"

local version="$(cat ${DIR}/version.txt)"
echo "current version is '${version}'"
```

The same applies for directory changes, which should always be done in a subshell to ensure we are not messing with the
shell state of the caller.

```shell
(
    cd "${DIR}/infrastructure"
    terraform apply
)
```

Despite all our best efforts, sometimes we might need to run some extra code to account for differences between 
CI/CD and our local machine. We should try to keep those differences as small as possible. In case it is needed, 
we can detect where we are executed depending on the de-facto-standard `CI` environment variable. 

```shell
if [[ -n "${CI:-}" ]]; then
    echo "we are running in CI, setting build typ to 'production'"
    export BUILD_TYPE="production"
fi
```

> Solidblocks provides a [ci_detected](https://pellepelster.github.io/solidblocks/shell/ci/index.html#ci_detected) 
> helper function for CI/CD detection that covers the most commonly used systems.

{{% /tab %}}
{{< /tabs >}}

## Interacting with other commands

When interacting with local commands or external data sources we want to avoid manually parsing data using regular 
expressions, or tools like `awk` and `sed`. If the datasource offers a structured machine-parsable format like JSON 
we should consume that with the appropriate tooling. For commands that do not offer a structured output, tools 
like [jc](https://kellyjonbrazil.github.io/jc/) can help us to make the output easily parsable.

{{< tabs groupId="parsing">}}
{{% tab name="Bash" %}}

Extract information from JSON data using `jq`.

```shell
local ip_addr="$(curl --silent ifconfig.me/all.json | jq -r '.ip_addr')"
echo "starting deployment, local ip address is '${ip_addr}'"
```

If a tool does not expose JSON, `jc` might be able to convert it.

```shell
local use_percent="$(df / | jc --df | jq '.[0].use_percent')"
echo "cleaned up repository, '/' has now ${use_percent}% free"
```

{{% /tab %}}
{{< /tabs >}}

## Execution Environment

### Fail Early

Nothing is more annoying than executing a long-running task only to notice at the end that some needed tool is missing,
or a minor configuration was not set correctly. To avoid this, we should check the execution environment first, and
fail with a meaningful error message as fast as possible. In the best case, the error message should not only say what is 
missing, but also give hints on how to fix it.

{{< tabs groupId="fail">}}
{{% tab name="Bash" %}}

In the shell a quick check, for the existence of the command may already be enough.

```shell
function ensure_environment() {
  if ! which tgswitch; then
    echo "tgswitch not found, please install it from https://github.com/warrensbox/tgswitch"
    exit 1
  fi
}

ensure_environment
```

Especially important for Bash is to check mandatory arguments and validate them before they are used.

```shell
local build_type=${1:-}

if [[ -z "${build_type}" ]]; then
    echo "no build type provided"
    exit 1
fi
echo "building the project with build type '${build_type}'"
```

{{% /tab %}}
{{< /tabs >}}

### Environment Preparation

To make the developer's life easier, we should consider how they are supposed to install the needed software to 
execute the `do` file. In general, we do not want to mess with the developer's system to install software, or make 
any assumptions about how the system is configured. So if we need a specific command that is generally available in the 
package managers of the operating systems we need to support, a small hint on how to install it goes a long way.

{{< tabs groupId="preparation">}}
{{% tab name="Bash" %}}

In the shell a quick check for the existence of the command may already be enough.

```shell
function ensure_environment() {
  if ! which jq; then
    echo "jq not found, please install it via 'apt-get install jq'"
    exit 1
  fi
}

ensure_environment
```

{{% /tab %}}
{{< /tabs >}}

### Downloading External Dependencies

Sometimes when a software package is not commonly available, we might want to go the extra mile and download it, 
so the developer does not have to fight with installing software and making it available on the `PATH`.
If we do this, we should again avoid littering the developer's system and keep the changes local to the repository. 
Also, we must not trust anything we fetch from the internet and always verify the checksum of everything 
we download.

{{< tabs groupId="dependencies">}}
{{% tab name="Bash" %}}

```shell
HUGO_VERSION="0.123.6"
HUGO_SHA256="be3a20ea1f585e2dc71bc9def2e505521ac2f5296a72eff3044dbff82bd0075e"

function ensure_hugo() {
  mkdir -p "${BIN_DIR}"

  local hugo_distribution="${BIN_DIR}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz"
  if [[ ! -f "${hugo_distribution}" ]] || ! echo "${HUGO_SHA256}"  "${hugo_distribution}" | sha256sum -c; then
    curl -L "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz" -o "${hugo_distribution}"
  fi
  echo "${HUGO_SHA256}"  "${hugo_distribution}" | sha256sum -c

  if [[ ! -f "${BIN_DIR}/.hugo_extracted" ]]; then
    tar -xvf "${hugo_distribution}" -C "${BIN_DIR}"
    touch "${BIN_DIR}/.hugo_extracted"
  fi
}

function task_build_documentation() {
  ensure_hugo
  "${BIN_DIR}/hugo" version
}
```

{{% /tab %}}
{{< /tabs >}}


## Make Tasks Resumable

We should factor in that our `do` file might get cancelled or interrupted at any time. This has implications for tasks
that, e.g. decompress files and are interrupted mid-compress leaving us with a partial state. To avoid this, 
we should design such tasks in a way that they can cope with interruptions and continue and/or restart where needed.

{{< tabs groupId="resume">}}
{{% tab name="Bash" %}}

```shell
if [[ ! -f "${TEMP_DIR}/.extracted" ]]; then
    tar -xvf "some_compressed_file.tgz" -C "${TEMP_DIR}"
    touch "${TEMP_DIR}/.extracted"
fi
```

{{% /tab %}}
{{< /tabs >}}


## Help


Although a `do` file is a nice entry to the repository you still might want to provide the developer with
hints on what tasks are available and how they are supposed to be used.


{{< tabs groupId="help">}}
{{% tab name="Bash" %}}

Unfortunately for bash there is no reliable way to automatically document the tasks for the user. The easiest 
way is to  create a help page that needs to be manually updated everytime a task is changed.
The help page will get printed if no task is provided to the `do` file.

```shell

# [...]

function task_usage {
  echo "Usage: $0

  build [debug|production]   build the project
  test  (parallel)           run integration tests
  clean                      remove all ephemeral files
  "
  exit 1
}

ARG=${1:-}
shift || true

case ${ARG} in
  build) task_build $@ ;;
  test)  task_test $@ ;;
  *) task_usage;;
esac
```

{{% /tab %}}
{{< /tabs >}}

## Secrets

Especially for tasks that deploy infrastructure we often need API keys or similar secrets. Assuming they are 
available in some form of password manager it is good practice to directly read them from there in the `do` file. 
This avoids forcing the user to prepare the environment by themselves which could lead to secrets being accidentally 
added to the user's shell history. We have to keep in mind though, that password managers often need interactive steps 
from the user to unlock, so we need to have a way for the CI/CD systems to provide secrets as well, which is commonly 
is done using environment variables.

{{< tabs groupId="secrets">}}
{{% tab name="Bash" %}}

For posix based environments [pass](https://www.passwordstore.org/), is an automation-friendly password manager that can
be used to securely handle sensitive data.   

```shell
local some_secret="${SOME_SECRET:-$(pass some_secret)}"
export TF_VAR_some_secret="${some_secret}"
```

If you really need to create a file containing sensitive information, make sure it has the minimal needed privileges 
and make sure it is cleaned up automatically by putting it into the `TEMP_DIR`.

```shell
local secrets_file="${TEMP_DIR}/secrets.txt"
install -m 600 /dev/null "${secrets_file}"
echo "a confidential string" > "${secrets_file}"
```

{{% /tab %}}
{{< /tabs >}}


## Clean up your mess

For all your temporary files it's a good idea to have a dedicated temp directory inside the project directory to ensure
we are not littering the system with temporary files. As we might even handle sensitive data inside of it, this 
also prevents us from accidentally exposing secrets to the systems `tmp` folder in case we forget to set the correct 
permissions. If you rely on larger binary blobs or tools from external sources, it might make sense to cache them in a 
dedicated directory to avoid re-downloading them every time they are needed. Finally, it's also a good idea to provide 
a cleanup-task that removes all this ephemeral data and resets your repository to a clean known state.


{{< tabs groupId="cleanup">}}
{{% tab name="Bash" %}}

We can leverage Bash's `trap` mechanism to make sure temporary files are removed after each `do` file run. 
Making the temp directory distinct using the current process id (`$$`) of the `do` file run, ensures the file can be invoked 
multiple times in parallel.

```shell
DIR="$(cd "$(dirname "$0")" ; pwd -P)"

TEMP_DIR="${DIR}/.temp"
mkdir -p "${TEMP_DIR}"

function clean_temp_dir {
  rm -rf "${TEMP_DIR}"
}

trap clean_temp_dir EXIT
```

```shell
BIN="${DIR}/.bin"

function task_clean() {
  clean_temp_dir
  rm -rf "${BIN_DIR}"
}

ARG=${1:-}
shift || true

case ${ARG} in
  clean) task_clean $@ ;;
  version) task_version $@ ;;
  *) task_usage;;
esac
```

{{% /tab %}}
{{< /tabs >}}


## Final thoughts

It is important to keep in mind, not to go overboard with complex algorithms in bash. If things get too complicated, or you
need to talk to third-party APIs, Python may be a more sensible choice. You can also combine both, and use bash to orchestrate 
some simple command calls leaving Python for all other more complex tasks.
