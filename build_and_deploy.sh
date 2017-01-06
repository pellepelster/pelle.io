#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

hugo

ncftpput -R -v -u ${FTP_USER} -p ${FTP_PASSWORD}  ${FTP_HOST} / ${DIR}/public/*