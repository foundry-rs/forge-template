#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy.
GreeterAddr=$(deploy Greeter)
log "Greeter deployed at:" $GreeterAddr
