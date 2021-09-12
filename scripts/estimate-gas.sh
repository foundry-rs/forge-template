#!/usr/bin/env bash

set -eo pipefail

. $(dirname $0)/common.sh

if [[ -z $contract ]]; then
  if [[ -z ${1} ]];then
    echo '"$contract" env variable is not set. Set it to the name of the contract you want to estimate gas cost for.'
    exit 1
  else
    contract=${1}
  fi
fi

estimate_gas $contract


