#!/bin/bash
npx ts-node \
contract-deployer.ts \
--cosmos-node="http://localhost:26656" \
--eth-node="[NODE END-POINT]" \
--eth-privkey="[PRIVATE-KEY]" \
--contract=Gravity.json \
--contractERC721=GravityERC721.json \
--test-mode=true
