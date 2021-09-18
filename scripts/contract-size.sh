#!/usr/bin/env bash

set -eo pipefail

. $(dirname $0)/common.sh

if [[ -z $contract ]]; then
  if [[ -z ${1} ]];then
    echo '"$contract" env variable is not set. Set it to the name of the contract you want to estimate size for.'
    exit 1
  else
    contract=${1}
  fi
fi
contract_size=$(contract_size ${contract})
echo "Contract Name: ${contract}"
echo "Contract Size: ${contract_size} bytes"
echo "$(( 24576 - ${contract_size} )) bytes left to reach the smart contract size limit of 24576 bytes."
