---
title: "Solidblocks Shell Software"
date: 2023-01-19T19:00:00
draft: false
tags: ["pdx"]
---

Referring to a previous post about [developer experience](/posts/project-developer-experience-do-file/), a re-occurring need when writing automation and/or glue code for software or infrastructure projects is to ensure all required software is installed on the execution machine. 
A lot of software exists to achieve this goal, e.g. [NixOS](https://nixos.org/) or [asdf](https://asdf-vm.com/), but sometimes a little bash can be enough to get the same results. [Solidblocks Shell Software](https://pellepelster.github.io/solidblocks/shell/software/) provides a small set of easy to use functions to install commonly used software for infrastructure projects.

The basic building blocks are the `software_ensure_*` functions like `software_ensure_terraform` which ensures that a certain software package is downloaded to a local `.bin` dir. Those software packages can then be prepended to the `$PATH` by the `software_set_export_path` function. For more details see [Solidblocks Shell Software](https://pellepelster.github.io/solidblocks/shell/software/)

The example below show a skeleton `do-file` leveraging this functionality

```shell
#!/usr/bin/env bash

set -eu -o pipefail

DIR="$(cd "$(dirname "$0")" ; pwd -P)"

# self contained function for initial solidblocks bootstrapping
function bootstrap_solidblocks() {
  local default_dir="$(cd "$(dirname "$0")" ; pwd -P)"
  local install_dir="${1:-${default_dir}/.solidblocks-shell}"

  SOLIDBLOCKS_SHELL_VERSION="v0.0.68"
  SOLIDBLOCKS_SHELL_CHECKSUM="1a7bb1d03b35e4cb94d825ec542d6f51c2c3cc1a3c387b0dea61eb4be32760a7"

  local temp_file="$(mktemp)"

  mkdir -p "${install_dir}"
  curl -L "https://github.com/pellepelster/solidblocks/releases/download/${SOLIDBLOCKS_SHELL_VERSION}/solidblocks-shell-${SOLIDBLOCKS_SHELL_VERSION}.zip" > "${temp_file}"
  echo "${SOLIDBLOCKS_SHELL_CHECKSUM}  ${temp_file}" | sha256sum -c
  cd "${install_dir}"
  unzip -o -j "${temp_file}" -d "${install_dir}"
  rm -f "${temp_file}"
}

# makes sure all lib functions are available
# and all bootstrapped software is on the $PATH
function ensure_environment() {

  if [[ ! -d "${DIR}/.solidblocks-shell" ]]; then
    echo "environment is not bootstrapped, please run ./do bootstrap first"
    exit 1
  fi

  source "${DIR}/.solidblocks-shell/log.sh"
  source "${DIR}/.solidblocks-shell/utils.sh"
  source "${DIR}/.solidblocks-shell/pass.sh"
  source "${DIR}/.solidblocks-shell/colors.sh"
  source "${DIR}/.solidblocks-shell/software.sh"

  software_set_export_path
}

# bootsrapping of solidblocks and all
# needed software for the project
function task_bootstrap() {
  bootstrap_solidblocks
  ensure_environment

  software_ensure_terragrunt
  software_ensure_terraform
}

# run the downloaded terraform version, ensure_environment ensures
# the downloaded versions takes precedence over any system binaries
function task_terraform {
  terraform -version
}

#
function task_usage {
  cat <<EOF
Usage: $0

  bootstrap               initialize the development environment

  ${FORMAT_BOLD}deployment${FORMAT_RESET}

    terraform             run terraform
EOF
  exit 1
}

ARG=${1:-}
shift || true

# if we see the boostrap command assume solidshell is not yet initialized and skip environment setup
case "${ARG}" in
  bootstrap) ;;
  *) ensure_environment ;;
esac

case ${ARG} in
  bootstrap) task_bootstrap "$@" ;;
  terraform) task_terraform "$@" ;;
  *) task_usage ;;
esac
```