---
title: "Project Developer Experience"
date: 2022-09-04T20:00:00+01:00
draft: true
---

A personal pet peeve of mine when joining a new project or environment is the developer experience (DX). Under this rather wide umbrella term I summarize everything that is needed to get a project running, tested and deployed apart from the actual business code itself. Starting on the local development environment setup, over being able to build and test locally to finally being able to deploy.

In this post I will try to visit some recurring problems and obstacles and give and some heavily opinionated and patterns on how to solve them.

> Some of the following example make use of a library available at https://pellepelster.github.io/solidblocks/ where I implemented some of the more common patterns.  

<!--more-->

## The do file


<!--
### Modules

For larger projects, especially in mono-repository setups adding everything into a single file is not feasible anymore. The best way to deal with situations like this is to follow the projects structure and split up the `do` file into multiple files in the according subfolders of the project, while still keeping the root `do` file orchestrating everything.  
-->

### Provide Help

Although providing a `do` or `go` file is always a good entrypoint for a developer, providing some help on how to use it makes the interaction even more enjoyable. Given the previously explained structure, we can use the default case to show a help text explaining the available commands:

```
function task_usage {
  echo "Usage: $0

  bootstrap               initialize the development environment

  ${FORMAT_BOLD}development${FORMAT_RESET}

    build                 build the backend
    
    [...]
    "

  exit 1
}


ARG=${1:-}
shift || true
case ${ARG} in

    [...]

    *) task_usage ;;
esac
```

will result in the following output if no or an invalid command is provided

```
$ ./do      
Usage: ./do

  bootstrap               initialize the development environment

  development

    build                 build the backend
    test                  run the backend integration tests

    ssh                   <environment>         open ssh session to the environments host
    db-tunnel             <environment>         open database tunnel to the hosts postgres db
```


### Ensure environment and  Provide (init pass)



### Tasks

clean/generate/build/test/deploy




## Tooling Setup

Depending on the technology used for implementation you may need some language specific tooling, let it be node/npm for Javascript projects, Terraform for infrastructure deployment or just jq to fiddle around with some JSON on the command line.

In order to keep the project repository self-contained we want to avoid installing software system-wide, as this also introduces potential version conflicts, especially with fast-paced tools like Terraform. Also, available tool versions may vary between different package managers, Arch Linux may already have the newest node version, but in Debian we have to be content with the latest stable version from two years ago.

### Install Locally

If possible installing the tools locally in the project folder can be a good solution to ensure a consistent environment across all developer machines and in the CI.

The pattern here is to download all needed binaries to a bin folder inside the project `${projectRoot}/.bin` and then to update the `PATH` to include the download binaries from the  

`export PATH="${PATH}:${projectRoot}/.bin`

A slightly advanced implemenation of this pattern is available [here](https://pellepelster.github.io/solidblocks/shell/software/) and can be used like this

```
source "software.sh"

software_ensure_terraform
software_set_export_path

# terraform is now included in the PATH and can directly be used
terraform apply [...]                                                                    
```

### Verify Environment

If a local installation is not possible, and we need to depend on system-wide software, we should at least make sure that everything that is needed is available.
Nothing is more annoying than to discover after a 15-minute build and test cycle that something was missing and the process fails during the last step. To avoid this problem before running anything we always want to make sure, all needed tooling is present

```
XXX
```

### Run From Docker

XXX

### Version

### Secret Handling



do not rely on working dir
provide a docker build
don't assume anything and give tips
do not pollute the system
use env manager for tech
version with default
versioning
temp dir
tasks
clean
bootstrap

verify environment (wherever possible validate input and give meaningful help)

