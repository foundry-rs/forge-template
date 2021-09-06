# All contracts are output to `out/addresses.json` by default
OUT_DIR=${OUT_DIR:-$PWD/out}
ADDRESSES_FILE=${ADDRESSES_FILE:-$OUT_DIR/"addresses.json"}
# default to localhost rpc
ETH_RPC_URL=${ETH_RPC_URL:-http://localhost:8545}

# green log helper
GREEN='\033[0;32m'
NC='\033[0m' # No Color
log() {
    printf '%b\n' "${GREEN}${*}${NC}"
    echo ""
}

# ensure ETH_FROM is set and give a meaningful error message
if [[ -z ${ETH_FROM} ]]; then
    echo "ETH_FROM not found, please set it and re-run the last command."
    exit 1
fi

# Setup addresses file
cat > "$ADDRESSES_FILE" <<EOF
{
    "DEPLOYER": "$(seth --to-checksum-address "$ETH_FROM")"
}
EOF

# Call as `ETH_FROM=0x... ETH_RPC_URL=<url> deploy ContractName arg1 arg2 arg3`
# (or omit the env vars if you have already set them)
deploy() {
    NAME=$1
    ARGS=${@:2}
    # select the filename and the contract in it
    PATTERN=".contracts[\"src/$NAME.sol\"].$NAME"

    # get the constructor's signature
    ABI=$(jq -r "$PATTERN.abi" out/dapp.sol.json)
    SIG=$(echo $ABI | seth --abi-constructor)

    # get the bytecode from the compiled file
    BYTECODE=0x$(jq -r "$PATTERN.evm.bytecode.object" out/dapp.sol.json)

    # estimate gas
    GAS=$(seth estimate --create $BYTECODE $SIG $ARGS --rpc-url $ETH_RPC_URL)

    # deploy
    ADDRESS=$(dapp create $NAME $ARGS -- --gas $GAS --rpc-url $ETH_RPC_URL)

    # save the addrs to the json
    # TODO: It'd be nice if we could evolve this into a minimal versioning system
    # e.g. via commit / chainid etc.
    saveContract $NAME $ADDRESS

    echo $ADDRESS
}

# Call as `saveContract ContractName 0xYourAddress` to store the contract name
# & address to the addresses json file
saveContract() {
    # create an empty json if it does not exist
    if [[ ! -e $ADDRESSES_FILE ]]; then
        echo "{}" > $ADDRESSES_FILE
    fi
    result=$(cat $ADDRESSES_FILE | jq -r ". + {\"$1\": \"$2\"}")
    printf %s "$result" > "$ADDRESSES_FILE"
}
