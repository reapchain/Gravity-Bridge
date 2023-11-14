import { ethers } from "ethers";
import fs from "fs";
import commandLineArgs from "command-line-args";
import axios, { AxiosError, AxiosRequestConfig, AxiosResponse } from "axios";
import { exit } from "process";

const args = commandLineArgs([
    // the ethernum node used to deploy the contract
    { name: "eth-node", type: String },
    // the cosmos node that will be used to grab the validator set via RPC (TODO),
    { name: "cosmos-node", type: String },
    // the Ethereum private key that will contain the gas required to pay for the contact deployment
    { name: "eth-privkey", type: String },
    // the gravity contract .json file
    { name: "contract", type: String },
    // the gravityERC721 contract .json file
    { name: "contractERC721", type: String },
    // test mode, if enabled this script deploys three ERC20 contracts for testing
    { name: "test-mode", type: String },
  ]);

async function main(){
    console.log("#### Test ####")
    const provider = await new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");
    //let wallet = new ethers.Wallet("0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122", provider);

    const blockNumber = await provider.getBlockNumber();

    console.log("==> ", blockNumber)
}

main()