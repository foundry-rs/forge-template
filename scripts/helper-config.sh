#!/usr/bin/env bash

# Defaults
# Add your defaults here
# For example:
# address=0x01be23585060835e02b77ef475b0cc51aa1e0709

# Add your contract arguments default here
arguments=""

if [ "$NETWORK" = "rinkeby" ]
then 
    : # Add arguments only for rinkeby here!
    # like: 
    # address=0x01be23585060835e02b77ef475b0cc51aa1e0709
elif [ "$NETWORK" = "mainnet" ]
then 
    : # Add arguments only for mainnet here!
    # like: 
    # address=0x01be23585060835e02b77ef475b0cc51aa1e0709
fi

if [ "$CONTRACT" = "Greeter" ]
then 
    : # Add conditional arguments here for contracts
    # arguments=$interval
fi 
