#!/bin/bash
set -eux
# your gaiad binary name
BIN=gravity

CHAIN_ID="reap-gravity-test"

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

ETHEREUM_KEY="0x986155CA1CEBc1E1412b371742Ab2704b1b42158"

ALLOCATION="1000000000stake"
#ALLOCATION="10000000000stake,10000000000footoken,10000000000footoken2,10000000000ibc/nometadatatoken"

# first we start a genesis.json with validator 1
# validator 1 will also collect the gentx's once gnerated
STARTING_VALIDATOR=1
ROOT_HOME=./node_data
STARTING_VALIDATOR_HOME=$ROOT_HOME/validator$STARTING_VALIDATOR

rm -rf $ROOT_HOME
mkdir $ROOT_HOME

# todo add git hash to chain name
$BIN init --home $STARTING_VALIDATOR_HOME --chain-id=$CHAIN_ID validator1

## Modify generated genesis.json to our liking by editing fields using jq
## we could keep a hardcoded genesis file around but that would prevent us from
## testing the generated one with the default values provided by the module.

# Set the chain's native bech32 prefix
jq '.app_state.bech32ibc.nativeHRP = "gravity"' $ROOT_HOME/validator$STARTING_VALIDATOR/config/genesis.json > $ROOT_HOME/gov-genesis.json

mv $ROOT_HOME/gov-genesis.json $ROOT_HOME/genesis.json

# Sets up an arbitrary number of validators on a single machine by manipulating
# the --home parameter on gaiad
for i in $(seq 1 $NODES);
do
GAIA_HOME=$ROOT_HOME/validator$i
GENTX_HOME="--home-client $ROOT_HOME/validator$i"
ARGS="--home $GAIA_HOME --keyring-backend test"

# Generate a validator key, orchestrator key, and eth key for each validator
$BIN keys add $ARGS validator$i 2>> $ROOT_HOME/validator-phrases
$BIN keys add $ARGS orchestrator$i 2>> $ROOT_HOME/orchestrator-phrases
#$BIN eth_keys add >> $ROOT_HOME/validator-eth-keys

VALIDATOR_KEY=$($BIN keys show validator$i -a $ARGS)
ORCHESTRATOR_KEY=$($BIN keys show orchestrator$i -a $ARGS)
# move the genesis in
mkdir -p $ROOT_HOME/validator$i/config/
mv $ROOT_HOME/genesis.json $ROOT_HOME/validator$i/config/genesis.json
$BIN add-genesis-account $ARGS $VALIDATOR_KEY $ALLOCATION
$BIN add-genesis-account $ARGS $ORCHESTRATOR_KEY $ALLOCATION

# move the genesis back out
mv $ROOT_HOME/validator$i/config/genesis.json $ROOT_HOME/genesis.json
done

for i in $(seq 1 $NODES);
do
cp $ROOT_HOME/genesis.json $ROOT_HOME/validator$i/config/genesis.json
GAIA_HOME=$ROOT_HOME/validator$i
ARGS="--home $GAIA_HOME --keyring-backend test"
ORCHESTRATOR_KEY=$($BIN keys show orchestrator$i -a $ARGS)
#ETHEREUM_KEY=$(grep address $ROOT_HOME/validator-eth-keys | sed -n "$i"p | sed 's/.*://')

# the /8 containing 7.7.7.7 is assigned to the DOD and never routable on the public internet
# we're using it in private to prevent gaia from blacklisting it as unroutable
# and allow local pex
$BIN gentx $ARGS --home $GAIA_HOME --moniker validator$i --chain-id=$CHAIN_ID validator$i 500000000stake $ETHEREUM_KEY $ORCHESTRATOR_KEY
# obviously we don't need to copy validator1's gentx to itself
if [ $i -gt 1 ]; then
cp $ROOT_HOME/validator$i/config/gentx/* $ROOT_HOME/validator1/config/gentx/
fi
done

$BIN collect-gentxs --home $STARTING_VALIDATOR_HOME
GENTXS=$(ls $ROOT_HOME/validator1/config/gentx | wc -l)
cp $ROOT_HOME/validator1/config/genesis.json $ROOT_HOME/genesis.json
echo "Collected $GENTXS gentx"

# put the now final genesis.json into the correct folders
for i in $(seq 1 $NODES);
do
cp $ROOT_HOME/genesis.json $ROOT_HOME/validator$i/config/genesis.json
done
