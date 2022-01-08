#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# import config with arguments based on contract and network
. $(dirname $0)/helper-config.sh

# Deploy 
# Contract will be counter unless overriden on the command line
: ${CONTRACT:=Greeter}
echo "Deploying $CONTRACT to $NETWORK with arguments: $arguments"
Addr=$(deploy $CONTRACT $arguments)
log "$CONTRACT deployed at:" $Addr
