# ensure ETH_FROM is set and give a meaningful error message
if [[ -z ${ETH_FROM} ]]; then
    echo "ETH_FROM not found, please set it and re-run the last command."
    exit 1
fi

GREEN='\033[0;32m'
NC='\033[0m' # No Color

OUT_DIR=${OUT_DIR:-$PWD/out}
ADDRESSES_FILE="$OUT_DIR/addresses.json"

# default to localhost rpc
ETH_RPC_URL=${ETH_RPC_URL:-http://localhost:8545}

# ETH_FROM and ETH_RPC_URL are set globally
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

    saveContract $NAME $ADDRESS

    echo $ADDRESS
}

saveContract() {
    # create an empty json if it does not exist
    if [[ ! -e $ADDRESSES_FILE ]]; then
        echo "{}" > $ADDRESSES_FILE
    fi
    result=$(cat $ADDRESSES_FILE | jq -r ". + {\"$1\": \"$2\"}")
    printf %s "$result" > "$ADDRESSES_FILE"
}

# loads addresses as key-value pairs from $ADDRESSES_FILE and exports them as
# environment variables.
loadAddresses() {
    local keys

    keys=$(jq -r "keys_unsorted[]" "$ADDRESSES_FILE")
    for KEY in $keys; do
        VALUE=$(jq -r ".$KEY" "$ADDRESSES_FILE")
        export "$KEY"="$VALUE"
    done
}

# concatenates the args with a comma
join() {
    local IFS=","
    echo "$*"
}

log() {
    printf '%b\n' "${GREEN}${*}${NC}"
    echo ""
}

toUpper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

toLower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}
