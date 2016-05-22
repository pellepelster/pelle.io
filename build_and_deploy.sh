#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


HUGO=$(which hugo)
if ! [ -x "$HUGO" ] ; then
	export GOPATH=$HOME/go
	go get -v github.com/spf13/hugo
	HUGO=${GOPATH}/bin/hugo
fi

${HUGO}
