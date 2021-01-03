#!/usr/bin/env bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BIN_DIR="${DIR}/.bin"
TMP_DIR="${DIR}/.tmp"

HUGO_URL="https://github.com/gohugoio/hugo/releases/download/v0.67.0/hugo_0.67.0_Linux-64bit.tar.gz"
HUGO_CHECKSUM="49679173372c13886a214c0b61e32a91a511a8460c13f8c4ae1d0cb71afacf00"
HUGO_BIN="${BIN_DIR}/hugo"

function ensure_hugo {
  mkdir -p "${BIN_DIR}" || true
  mkdir -p "${TMP_DIR}" || true

  if [[ ! -f "${HUGO_BIN}"  ]]; then
    curl "${HUGO_URL}" -L --output "${TMP_DIR}/hugo.tar.gz"
    echo "${HUGO_CHECKSUM} ${TMP_DIR}/hugo.tar.gz" | sha256sum --check --status
    tar -C "${BIN_DIR}" -xvf "${TMP_DIR}/hugo.tar.gz"
  fi
}

function execute_hugo {
  ensure_hugo
  (
    cd "${DIR}/site"
    "${HUGO_BIN}" "$@"
  )
}

function task_deploy {
  echo "${DEPLOY_SSH_KEY}" > deploy_ssh
  chmod 600 deploy_ssh

  echo "put -R ${DIR}/site/public/* www" > deploy_batch
  echo "exit" >> deploy_batch
  sftp -o StrictHostKeyChecking=no -b deploy_batch -i deploy_ssh deploy@pelle.io
}
 
function task_build {
  execute_hugo
  cp -v "${DIR}/.htaccess" "${DIR}/site/public/"
}

function task_serve {
  execute_hugo "serve"
}

function task_usage {
  echo "Usage: $0 build | deploy"
  exit 1
}

CMD=${1:-}
shift || true
case ${CMD} in
  deploy) task_deploy ;;
  build) task_build ;;
  serve) task_serve ;;
  *) task_usage ;;
esac
