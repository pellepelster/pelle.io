#!/usr/bin/env bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BIN_DIR="${DIR}/.bin"
TMP_DIR="${DIR}/.tmp"

HUGO_URL="https://github.com/gohugoio/hugo/releases/download/v0.88.1/hugo_0.88.1_Linux-64bit.tar.gz"
HUGO_CHECKSUM="80cbb0b12a03838a1f053849c9d3accad1f328a8ea824294d57f9a0c6f89620b"
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

  echo "put -R ${DIR}/site/public/* /" > deploy_batch
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
  echo "Usage: $0 build | serve | deploy"
  exit 1
}

CMD=${1:-}
shift || true
case ${CMD} in
  build) task_build ;;
  serve) task_serve ;;
  deploy) task_deploy ;;
  *) task_usage ;;
esac
