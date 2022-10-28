---
title: "The do file"
subtitle: Project Developer Experience
date: 2022-10-27T20:00:00+01:00
draft: false
tags: ["pdx"]
---

The first question after cloning a new repository often is: "How do I build this thing?", immediately followed by "...and how do I run this thing?". There may be a README.MD somewhere with some information about some commands that you can run, but this information tends to get outdated very fast.

A simple shell script can serve as an entrypoint for all tasks needed to work with the content of a repository.  You can name it any way you want, I like to call them `do` or `go` as the name implies that something can be done here (comparable to the interface of older point-and-click adventures).

Keeping in mind different developer machines that may run under Linux, Windows or OSX since the introduction of the Linux subsystem for Windows, the bash shell is a reasonable lowest common denominator to chose as a scripting language that works across all major operating systems.

Purpose of the `do` file is to put all steps needed to interact with the project in code. Ideally this code can also be used in the CI/CD environment, so we keep the local machine close to the CI and vice-versa making it easier to debug potential problems.

## File Header

This common file header ensures we are using bash for maximum portability. Also, some safe settings ensuring our scripts returns early in case something goe wrong.

```shell
#!/usr/bin/env bash

# exit early if any command fails instead of running the ret of the script
set -o errexit

# fail the script when accessing an unset variable
set -o nounset

# also ensure early fail fore piped commands
set -o pipefail

# enable setting trace mode via the TRACE environment variable
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

# get the directory containing the do file
DIR="$(cd "$(dirname "$0")" ; pwd -P)"
```

## Structure

To add some structure to the do file, splitting the functionality into simple bash functions is a good way to ensure the file does not deteriorate into a thousand lines of spaghetti code. I like to use the naming convention of `task_${name}` for functions that can be called by the user:

```shell
function task_build() {
    echo "building the project..."
}

function task_deploy() {
    echo "deploying the project..."
}
```

Those functions then get dispatched by a case-switch at the end of the file:

```shell
ARG=${1:-}
shift || true

case ${ARG} in
  build) task_build "$@" ;;
  deploy) task_deploy "$@" ;;
    
  [...]
  
esac
```

making them easily callable from the shell, for example:

```shell
$ ./do build
building the project...
```

## Execution Context

Having the goal to be used on a developer machine, as well as in the CI, you should never assume that the working directory is correctly set. Always give the full path when referencing files using the `DIR` variable introduced in the file header.

```shell

function task_build() {
  "${DIR}/gradlew" build test
}
```

The same applies for directory changes, that should always be done in a subshell to ensure we are not messing with the terminal state of the caller.

```shell
function task_deploy() {
  (
    cd "${DIR}/infarstructure"
    terraform apply
  )
}
```

## Clean up your mess

For all your temporary files it's a good idea to have a dedicated temp directory inside the project directory to ensure we are not littering the executing system with temporary files. By automatically cleaning this up using bash's trap mechanism we make sure the project is clean after each `do` file run. Cleaning up after the `do`file run also ensures we are not accidentally leaking any secrets that may be stored in this folder. Making the temp directory distinct using the current process id (`$$`) of the `do` file run ensures the file can be invoked multiple times in parallel.

```shell
TEMP_DIR="${DIR}/.tmp.$$"
mkdir -p "${TEMP_DIR}"

function cleanup {
  rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

function task_build() {
    date +%Y%m%d%H%M%S > "${TEMP_DIR}/version.txt"
}

```
## Final thoughts

Important to keep in mind is not to go overboard with complex algorithms in bash. If things get to complicated, or you need to talk to third-party APIs, Python or Ruby may be a more sensible choice.
