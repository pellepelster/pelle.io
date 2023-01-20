#!/usr/bin/env bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function bootstrap_solidblocks() {
  local default_dir="$(cd "$(dirname "$0")" ; pwd -P)"
  local install_dir="${1:-${default_dir}/.solidblocks-shell}"

  SOLIDBLOCKS_SHELL_VERSION="v0.0.65"
  SOLIDBLOCKS_SHELL_CHECKSUM="b24f0a60d5d7e713b8706f6b898a5467d6ac768542b86ac079e9d9a7fde9ed01"

  local temp_file="$(mktemp)"

  mkdir -p "${install_dir}"
  curl -L "https://github.com/pellepelster/solidblocks/releases/download/${SOLIDBLOCKS_SHELL_VERSION}/solidblocks-shell-${SOLIDBLOCKS_SHELL_VERSION}.zip" > "${temp_file}"
  echo "${SOLIDBLOCKS_SHELL_CHECKSUM}  ${temp_file}" | sha256sum -c
  cd "${install_dir}"
  unzip -o -j "${temp_file}" -d "${install_dir}"
  rm -f "${temp_file}"
}

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

function task_bootstrap() {
  bootstrap_solidblocks
  ensure_environment

  software_ensure_hugo
}

function hugo_wrapper {
  (
    cd "${DIR}/site"
    hugo "$@"
  )
}

function task_deploy {
  echo "${DEPLOY_SSH_KEY}" > deploy_ssh
  chmod 600 deploy_ssh

  echo "put -R ${DIR}/site/public/* /" > deploy_batch
  echo "exit" >> deploy_batch
  sftp -o StrictHostKeyChecking=no -b deploy_batch -i deploy_ssh deploy@pelle.io
}
 
function task_build {
  hugo_wrapper
  cp -v "${DIR}/.htaccess" "${DIR}/site/public/"
}

function task_serve {
  hugo_wrapper "serve"
}

function task_usage {
  echo "Usage: $0 build | serve | deploy"
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
  build) task_build ;;
  serve) task_serve ;;
  deploy) task_deploy ;;
  *) task_usage ;;
esac

