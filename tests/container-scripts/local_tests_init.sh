#!/bin/bash

#set -eux

LOG_LEVEL="debug"

killall -9 gravity
killall -9 gaiad
killall -9 hermes

rm -rf ~/bridge
./setup-validators.sh 1
./setup-ibc-validators.sh 1
mkdir ~/bridge/ibc-relayer-logs
touch ~/bridge/ibc-relayer-logs/hermes-logs
touch ~/bridge/ibc-relayer-logs/channel-creation

nohup gravity --home /Users/eddy/bridge/validator1 --address tcp://0.0.0.0:26655 --rpc.laddr tcp://0.0.0.0:26657 --grpc.address 0.0.0.0:9090 --grpc-web.address 0.0.0.0:9091 --log_level $LOG_LEVEL --inv-check-period 1 --p2p.laddr tcp://0.0.0.0:26656 start > ~/bridge/gravity.log 2>&1 &

sed -i.temp "s/laddr = \"tcp:\/\/0.0.0.0:26656\"/laddr = \"tcp:\/\/0.0.0.0:36656\"/g" ~/bridge/ibc-validator1/config/config.toml 
sed -i.temp "s/laddr = \"tcp:\/\/127.0.0.1:26657\"/laddr = \"tcp:\/\/127.0.0.1:36657\"/g" ~/bridge/ibc-validator1/config/config.toml 
sed -i.temp 's/address = "0.0.0.0:9090"/address = "0.0.0.0:9190"/g' ~/bridge/ibc-validator1/config/app.toml 
sed -i.temp 's/address = "0.0.0.0:9091"/address = "0.0.0.0:9191"/g' ~/bridge/ibc-validator1/config/app.toml 

nohup gaiad --home /Users/eddy/bridge/ibc-validator1 --log_level $LOG_LEVEL start > ~/bridge/ibc-gaiad.log 2>&1 &
