#!/usr/bin/env bash

set -eu -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BIN_DIR="${DIR}/.bin"
TMP_DIR="${DIR}/.tmp"

HUGO_URL="https://github.com/gohugoio/hugo/releases/download/v0.67.0/hugo_0.67.0_Linux-64bit.tar.gz"
HUGO_CHECKSUM="49679173372c13886a214c0b61e32a91a511a8460c13f8c4ae1d0cb71afacf00"
HUGO_BIN="${BIN_DIR}/hugo"


function task_deploy {
  ncftpput -R -v -u ${FTP_USERNAME:-$(pass 'pelle.io/ftp/userid')} -p ${FTP_PASSWORD:-$(pass 'pelle.io/ftp/password')} ftp.pelle.io / ${DIR}/public/*
}

function ensure_hugo {
  mkdir -p "${BIN_DIR}" || true
  mkdir -p "${TMP_DIR}" || true

  if [[ ! -f "${HUGO_BIN}"  ]]; then
    curl "${HUGO_URL}" -L --output "${TMP_DIR}/hugo.tar.gz"
    echo "${HUGO_CHECKSUM} ${TMP_DIR}/hugo.tar.gz" | sha256sum --check --status
    tar -C "${BIN_DIR}" -xvf "${TMP_DIR}/hugo.tar.gz"
  fi
}

function task_build {
  ensure_hugo
  (
    cd "${DIR}/site"
    ${HUGO_BIN}
  )
}

function task_usage {
  echo "Usage: $0 build | deploy"
  exit 1
}

CMD=${1:-}
shift || true
case ${CMD} in
  build) task_build ;;
  deploy) task_deploy ;;
  *) task_usage ;;
esac
