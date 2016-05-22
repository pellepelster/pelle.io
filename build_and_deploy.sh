#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "$OSTYPE" == "linux-gnu" ]]; then
	apt-get install hugo 
elif [[ "$OSTYPE" == "darwin"* ]]; then
	brew install hugo
fi


rm -rf "${DIR}/public"
hugo
