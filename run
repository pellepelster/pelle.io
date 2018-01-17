#!/bin/bash

set -eu -o pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function task_deploy {
  ncftpput -R -v -u ${FTP_USERNAME:-$(pass 'pelle.io/ftp/userid')} -p ${FTP_PASSWORD:-$(pass 'pelle.io/ftp/password')} ftp.pelle.io / ${DIR}/public/*
}

function task_build {
  cd ${DIR}
  hugo
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
