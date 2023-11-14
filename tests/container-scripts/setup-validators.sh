#!/bin/bash
set -eux
# your gaiad binary name
BIN=gravity

CHAIN_ID="gravity-test-1"

NODES=$1
# When doing an upgrade test we need to run init using the old binary so we don't include newly added fields
set +u
if [[ ! -z ${OLD_BINARY_LOCATION} ]]; then
  echo "Replacing gravity with $OLD_BINARY_LOCATION"
  BIN=$OLD_BINARY_LOCATION
else
  echo "Old binary not set, using regular gravity"
fi
set -u

ALLOCATION="10000000000stake,10000000000footoken,10000000000footoken2,10000000000ibc/nometadatatoken"

# first we start a genesis.json with validator 1
# validator 1 will also collect the gentx's once gnerated
STARTING_VALIDATOR=1
STARTING_VALIDATOR_HOME=~/bridge/validator$STARTING_VALIDATOR
# todo add git hash to chain name
$BIN init --home $STARTING_VALIDATOR_HOME --chain-id=$CHAIN_ID validator1


## Modify generated genesis.json to our liking by editing fields using jq
## we could keep a hardcoded genesis file around but that would prevent us from
## testing the generated one with the default values provided by the module.

# add in denom metadata for both native tokens
jq '.app_state.bank.denom_metadata += [{"name": "Foo Token", "symbol": "FOO", "base": "footoken", display: "mfootoken", "description": "A non-staking test token", "denom_units": [{"denom": "footoken", "exponent": 0}, {"denom": "mfootoken", "exponent": 6}]},{"name": "Stake Token", "symbol": "STEAK", "base": "stake", display: "mstake", "description": "A staking test token", "denom_units": [{"denom": "stake", "exponent": 0}, {"denom": "mstake", "exponent": 6}]}]' ~/bridge/validator$STARTING_VALIDATOR/config/genesis.json > ~/bridge/footoken2-genesis.json
jq '.app_state.bank.denom_metadata += [{"name": "Foo Token2", "symbol": "F20", "base": "footoken2", display: "mfootoken2", "description": "A second non-staking test token", "denom_units": [{"denom": "footoken2", "exponent": 0}, {"denom": "mfootoken2", "exponent": 6}]}]' ~/bridge/footoken2-genesis.json > ~/bridge/bech32ibc-genesis.json

# Set the chain's native bech32 prefix
jq '.app_state.bech32ibc.nativeHRP = "gravity"' ~/bridge/bech32ibc-genesis.json > ~/bridge/gov-genesis.json

# a 60 second voting period to allow us to pass governance proposals in the tests
jq '.app_state.gov.voting_params.voting_period = "120s"' ~/bridge/gov-genesis.json > ~/bridge/community-pool-genesis.json

# Add some funds to the community pool to test Airdrops, note that the gravity address here is the first 20 bytes
# of the sha256 hash of 'distribution' to create the address of the module
jq '.app_state.distribution.fee_pool.community_pool = [{"denom": "stake", "amount": "1000000000000000000000000.0"}]' ~/bridge/community-pool-genesis.json > ~/bridge/community-pool2-genesis.json
jq '.app_state.auth.accounts += [{"@type": "/cosmos.auth.v1beta1.ModuleAccount", "base_account": { "account_number": "0", "address": "gravity1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8r0kyvh","pub_key": null,"sequence": "0"},"name": "distribution","permissions": ["basic"]}]' ~/bridge/community-pool2-genesis.json > ~/bridge/community-pool3-genesis.json
jq '.app_state.bank.balances += [{"address": "gravity1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8r0kyvh", "coins": [{"amount": "1000000000000000000000000", "denom": "stake"}]}]' ~/bridge/community-pool3-genesis.json > ~/bridge/edited-genesis.json

mv ~/bridge/edited-genesis.json ~/bridge/genesis.json

VESTING_AMOUNT="1000000000stake"
START_VESTING=$(expr $(date +%s) + 300) # Start vesting 5 minutes from now
END_VESTING=$(expr $START_VESTING + 600) # End vesting 10 minutes from now, giving a 5 minute window for the test to work

# Sets up an arbitrary number of validators on a single machine by manipulating
# the --home parameter on gaiad
for i in $(seq 1 $NODES);
do
GAIA_HOME=~/bridge/validator$i
GENTX_HOME="--home-client ~/bridge/validator$i"
ARGS="--home $GAIA_HOME --keyring-backend test"

# Generate a validator key, orchestrator key, and eth key for each validator
$BIN keys add $ARGS validator$i 2>> ~/bridge/validator-phrases
$BIN keys add $ARGS orchestrator$i 2>> ~/bridge/orchestrator-phrases
$BIN eth_keys add >> ~/bridge/validator-eth-keys

VALIDATOR_KEY=$($BIN keys show validator$i -a $ARGS)
ORCHESTRATOR_KEY=$($BIN keys show orchestrator$i -a $ARGS)
# move the genesis in
mkdir -p ~/bridge/validator$i/config/
mv ~/bridge/genesis.json ~/bridge/validator$i/config/genesis.json
$BIN add-genesis-account $ARGS $VALIDATOR_KEY $ALLOCATION
$BIN add-genesis-account $ARGS $ORCHESTRATOR_KEY $ALLOCATION

# Add a vesting account
$BIN keys add $ARGS vesting$i 2>> ~/bridge/vesting-phrases
VESTING_KEY=$($BIN keys show vesting$i -a $ARGS)
$BIN add-genesis-account $ARGS $VESTING_KEY --vesting-amount $VESTING_AMOUNT --vesting-start-time $START_VESTING --vesting-end-time $END_VESTING $VESTING_AMOUNT

# move the genesis back out
mv ~/bridge/validator$i/config/genesis.json ~/bridge/genesis.json
done


for i in $(seq 1 $NODES);
do
cp ~/bridge/genesis.json ~/bridge/validator$i/config/genesis.json
GAIA_HOME=~/bridge/validator$i
ARGS="--home $GAIA_HOME --keyring-backend test"
ORCHESTRATOR_KEY=$($BIN keys show orchestrator$i -a $ARGS)
ETHEREUM_KEY=$(grep address ~/bridge/validator-eth-keys | sed -n "$i"p | sed 's/.*://')
# the /8 containing 7.7.7.7 is assigned to the DOD and never routable on the public internet
# we're using it in private to prevent gaia from blacklisting it as unroutable
# and allow local pex
$BIN gentx $ARGS --home $GAIA_HOME --moniker validator$i --chain-id=$CHAIN_ID validator$i 500000000stake $ETHEREUM_KEY $ORCHESTRATOR_KEY
# obviously we don't need to copy validator1's gentx to itself
if [ $i -gt 1 ]; then
cp ~/bridge/validator$i/config/gentx/* ~/bridge/validator1/config/gentx/
fi
done

$BIN collect-gentxs --home $STARTING_VALIDATOR_HOME
GENTXS=$(ls ~/bridge/validator1/config/gentx | wc -l)
cp ~/bridge/validator1/config/genesis.json ~/bridge/genesis.json
echo "Collected $GENTXS gentx"

# put the now final genesis.json into the correct folders
for i in $(seq 1 $NODES);
do
cp ~/bridge/genesis.json ~/bridge/validator$i/config/genesis.json
done
