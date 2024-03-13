#!/usr/bin/env bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

SITES="pelle.io solidblocks.de"
SOLIDBLOCKS_SHELL_VERSION="v0.2.5"
SOLIDBLOCKS_SHELL_CHECKSUM="d07eb3250f83ae545236fdd915feca602bdb9b683140f2db8782eab29c9b2c48"
TEMP_DIR="${DIR}/.temp"

mkdir -p "${TEMP_DIR}"

function clean_temp_dir {
  rm -rf "${TEMP_DIR}"
}

trap clean_temp_dir EXIT

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

function ensure_environment() {

  if [[ ! -d "${DIR}/.solidblocks-shell" ]]; then
    echo "environment is not bootstrapped, please run ./do bootstrap first"
    exit 1
  fi

  source "${DIR}/.solidblocks-shell/log.sh"
  source "${DIR}/.solidblocks-shell/utils.sh"
  source "${DIR}/.solidblocks-shell/pass.sh"
  source "${DIR}/.solidblocks-shell/text.sh"
  source "${DIR}/.solidblocks-shell/software.sh"

  software_set_export_path
}

function task_bootstrap() {
  bootstrap_solidblocks
  ensure_environment

  software_ensure_hugo "0.123.8" "3e628b6ba89fef2976640af2eb7724babbf7839c0b97d04d2b6958d35027c88d"
}

function hugo_wrapper {
  local site="${1:-}"
  shift || true
  (
    cd "${DIR}/${site}"
    hugo --themesDir "${DIR}/themes" --destination "${DIR}/output/${site}" "$@"
  )
}

function task_deploy {
  install -m 600 /dev/null "${TEMP_DIR}/deploy_ssh"
  echo "${DEPLOY_SSH_KEY}" > "${TEMP_DIR}/deploy_ssh"

  install -m 600 /dev/null "${TEMP_DIR}/deploy_batch"
  for site in ${SITES}; do
    echo "put -R ${DIR}/output/* public_html/" >> "${TEMP_DIR}/deploy_batch"
  done
  echo "exit" >> "${TEMP_DIR}/deploy_batch"

  sftp -o StrictHostKeyChecking=no -b "${TEMP_DIR}/deploy_batch" -i "${TEMP_DIR}/deploy_ssh" deploy@pelle.io
}
 
function task_build_all {
  for site in ${SITES}; do
    hugo_wrapper "${site}"
    cp -v "${DIR}/.htaccess" "${DIR}/output/${site}"
  done
}

function task_serve {
  local site="${1:-}"
  shift || true

  hugo_wrapper "${site}" "serve" --verbose --disableFastRender $@
}

function task_usage {
  echo "Usage: $0 build | serve | deploy"
  exit 1
}

ARG=${1:-}
shift || true

case "${ARG}" in
  bootstrap) ;;
  *) ensure_environment ;;
esac

case ${ARG} in
  bootstrap) task_bootstrap "$@" ;;
  build-all) task_build_all ;;
  hugo) hugo_wrapper $@ ;;
  serve) task_serve $@ ;;
  deploy) task_deploy ;;
  *) task_usage ;;
esac

