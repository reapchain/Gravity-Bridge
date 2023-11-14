#!/bin/bash
npx ts-node \
contract-deployer.ts \
--cosmos-node="http://localhost:26656" \
--eth-node="https://sepolia.infura.io/v3/6e7a5ddb55cc4d02b51a7d65830fca30" \
--eth-privkey="0x7fde2ff45e148d3f41e0797bb25dc3b2c0dc5d6f9664d4350c24a5cf3832ed48" \
--contract=Gravity.json \
--contractERC721=GravityERC721.json \
--test-mode=true
