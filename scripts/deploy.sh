# import helpers
# TODO: Can we make this import work from any directory?
. ./scripts/common.sh

# Setup addresses file
cat > "$ADDRESSES_FILE" <<EOF
{
    "DEPLOYER": "$(seth --to-checksum-address "$ETH_FROM")"
}
EOF

# Deploy.
GreeterAddr=$(deploy Greeter)
log "Greeter deployed at:" $GreeterAddr
