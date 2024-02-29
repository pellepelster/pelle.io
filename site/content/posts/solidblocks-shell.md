---
title: "Solidblocks Shell Software"
date: 2023-01-19T19:00:00
draft: true
tags: [ "pdx" ]
---

Referring to a previous post about [developer experience](/posts/project-developer-experience-do-file/), a re-occurring
need when writing automation and/or glue code for software or infrastructure projects is to ensure all required software
is installed on the execution machine.
A lot of software exists to achieve this goal, e.g. [NixOS](https://nixos.org/) or [asdf](https://asdf-vm.com/), but
sometimes a little bash can be enough to get the same
results. [Solidblocks Shell Software](https://pellepelster.github.io/solidblocks/shell/software/) provides a small set
of easy to use functions to install commonly used software for infrastructure projects.

The basic building blocks are the `software_ensure_*` functions like `software_ensure_terraform` which ensures that a
certain software package is downloaded to a local `.bin` dir. Those software packages can then be prepended to
the `$PATH` by the `software_set_export_path` function. For more details
see [Solidblocks Shell Software](https://pellepelster.github.io/solidblocks/shell/software/)

The example below show a skeleton `do-file` leveraging this functionality

```shell
#!/usr/bin/env bash

set -eu -o pipefail

DIR="$(cd "$(dirname "$0")" ; pwd -P)"

SOLIDBLOCKS_SHELL_VERSION="v0.1.15"
SOLIDBLOCKS_SHELL_CHECKSUM="12be1afac8ba2166edfa9eb01ca984aa7c1db4350cd8653a711394a22c3b599a"

# self contained function for initial Solidblocks bootstrapping
function bootstrap_solidblocks() {
  local default_dir="$(cd "$(dirname "$0")" ; pwd -P)"
  local install_dir="${1:-${default_dir}/.solidblocks-shell}"

  local temp_file="$(mktemp)"

  curl -v -L "${SOLIDBLOCKS_BASE_URL:-https://github.com}/pellepelster/solidblocks/releases/download/${SOLIDBLOCKS_SHELL_VERSION}/solidblocks-shell-${SOLIDBLOCKS_SHELL_VERSION}.zip" > "${temp_file}"
  echo "${SOLIDBLOCKS_SHELL_CHECKSUM}  ${temp_file}" | sha256sum -c

  mkdir -p "${install_dir}" || true
  (
      cd "${install_dir}"
      unzip -o -j "${temp_file}" -d "${install_dir}"
      rm -f "${temp_file}"
  )
}

# makes sure all needed shell functions functions are available and all bootstrapped software is on the $PATH
function ensure_environment() {

  if [[ ! -d "${DIR}/.solidblocks-shell" ]]; then
    echo "environment is not bootstrapped, please run ./do bootstrap first"
    exit 1
  fi

  # included needed shell functions
  source "${DIR}/.solidblocks-shell/log.sh"
  source "${DIR}/.solidblocks-shell/text.sh"
  source "${DIR}/.solidblocks-shell/software.sh"

  # ensure $PATH contains all software downloaded via the `software_ensure_*` functions
  software_set_export_path
}

# bootstrap Solidblocks, and all other software needed using the software installer helpers from https://pellepelster.github.io/solidblocks/shell/software/
function task_bootstrap() {
  bootstrap_solidblocks
  ensure_environment
  software_ensure_terraform
}

# run the downloaded terraform version, ensure_environment ensures the downloaded versions takes precedence over any system binaries
function task_terraform {
  terraform -version
}

function task_log {
    log_info "info message"
    log_success "success message"
    log_warning "warning message"
    log_debug "debug message"
    log_error "error message"
}

function task_text {
    echo "${FORMAT_DIM}Dim${FORMAT_RESET}"
    echo "${FORMAT_UNDERLINE}Underline${FORMAT_RESET}"
    echo "${FORMAT_BOLD}Bold${FORMAT_RESET}"
    echo "${COLOR_RED}Red${COLOR_RESET}"
    echo "${COLOR_GREEN}Green${COLOR_RESET}"
    echo "${COLOR_YELLOW}Yellow${COLOR_RESET}"
    echo "${COLOR_BLACK}Black${COLOR_RESET}"
    echo "${COLOR_BLUE}Blue${COLOR_RESET}"
    echo "${COLOR_MAGENTA}Magenta${COLOR_RESET}"
    echo "${COLOR_CYAN}Cyan${COLOR_RESET}"
    echo "${COLOR_WHITE}White${COLOR_RESET}"
}

# provide some meaningful help using shell formatting from https://pellepelster.github.io/solidblocks/shell/text/
function task_usage {
  cat <<EOF
Usage: $0

  bootstrap             initialize the development environment
  terraform             run terraform
  log                   log some stuff
  text                  print soe fancy text formats
EOF
  exit 1
}

ARG=${1:-}
shift || true

# if we see the bootstrap command assume Solidshell is not yet initialized and skip environment setup
case "${ARG}" in
  bootstrap) ;;
  *) ensure_environment ;;
esac

case ${ARG} in
  bootstrap) task_bootstrap "$@" ;;
  terraform) task_terraform "$@" ;;
  log)       task_log "$@" ;;
  text)      task_text "$@" ;;
  *) task_usage ;;
esac
```