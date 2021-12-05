import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-solhint";
import "@nomiclabs/hardhat-waffle";
import "hardhat-deploy";
import { fornoURLs, ICeloNetwork } from "@ubeswap/hardhat-celo";
import "dotenv/config";
import "hardhat-abi-exporter";
import { removeConsoleLog } from "hardhat-preprocessor";
import "hardhat-spdx-license-identifier";
import { HardhatUserConfig, task } from "hardhat/config";
import { HDAccountsUserConfig } from "hardhat/types";
import "solidity-coverage";
// task(
//   "addMobiusSwaps",
//   "Adds Mobius Swap contracts to the wrapper",
//   async (taskArguments: { pools: string }, hre, runSuper) => {
//     const { pools } = taskArguments;
//     const addresses = pools.split(",").map((s) => s.trim());
//     const mobiusWrapper = <MobiusWrapper>(
//       await hre.ethers.getContract("MobiusWrapper")
//     );
//     const txns = await Promise.all(
//       addresses.map(
//         async (swapAddress) =>
//           await mobiusWrapper.addSwapContract(swapAddress, 2)
//       )
//     );
//     console.log(txns);
//   }
// ).addParam("pools", "The addresses of mobius pools, comma separated");

// task(
//   "add-dex",
//   "Adds DEXes to minima",
//   async (
//     { dexAddresses, dexNames }: { dexAddresses: string; dexNames: string },
//     hre,
//     runSuper
//   ) => {
//     const addresses = dexAddresses.split(",").map((s) => s.trim());
//     const names = dexNames.split(",").map((s) => s.trim());
//     const minima = <Minima>await hre.ethers.getContract("Minima");
//     const txns = await Promise.all(
//       addresses.map(
//         async (swapAddress, i) => await minima.addDex(swapAddress, names[i])
//       )
//     );
//     console.log(txns);
//   }
// )
//   .addParam("dexAddresses", "The addresses of dexes, comma separated")
//   .addParam("dexNames", "The names of dexes, comma separated");

// task(
//   "add-tokens",
//   "Adds DEXes to minima",
//   async ({ tokens }: { tokens: string }, hre, runSuper) => {
//     const addresses = tokens.split(",").map((s) => s.trim());
//     const minima = <Minima>await hre.ethers.getContract("Minima");
//     const txns = await Promise.all(
//       addresses.map(
//         async (swapAddress, i) => await minima.addToken(swapAddress)
//       )
//     );
//     console.log(txns);
//   }
// ).addParam("tokens", "The addresses of tokens, comma separated");

// task(
//   "liveTest",
//   "Tests the connectors on the specified network",
//   async (...args: Parameters<ActionType<{ step: string }>>) => {
//     return await (await import("./tasks/tests")).test(...args);
//   }
// ).addParam("step", "The step to deploy");

// task("test", "Test the contracts", async () => {});
const accounts: HDAccountsUserConfig = {
  mnemonic:
    process.env.MNEMONIC ||
    "test test test test test test test test test test test junk",
  path: "m/44'/52752'/0'/0/",
};

// const accounts = [`0x${process.env.PRIVATE_KEY_DEV}`];

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
export default {
  abiExporter: {
    path: "./build/abi",
    flat: true,
  },
  defaultNetwork: "hardhat",
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  networks: {
    mainnet: {
      url: fornoURLs[ICeloNetwork.MAINNET],
      accounts,
      chainId: ICeloNetwork.MAINNET,
      live: true,
      gasPrice: 0.5 * 10 ** 9,
      gas: 8000000,
    },
    alfajores: {
      url: fornoURLs[ICeloNetwork.ALFAJORES],
      accounts,
      chainId: ICeloNetwork.ALFAJORES,
      live: true,
      gasPrice: 0.5 * 10 ** 9,
      gas: 8000000,
    },
    hardhat: {
      chainId: 31337,
      accounts,
    },
  },
  paths: {
    deploy: "deploy",
    sources: "./contracts",
    tests: "./test",
    cache: "./build/cache",
    artifacts: "./build/artifacts",
    imports: "imports",
    deployments: "deployments",
  },
  preprocess: {
    eachLine: removeConsoleLog(
      (bre) =>
        bre.network.name !== "hardhat" && bre.network.name !== "localhost"
    ),
  },
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 5000,
      },
    },
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT,
    username: process.env.TENDERLY_USERNAME,
  },
  watcher: {
    compile: {
      tasks: ["compile"],
      files: ["./contracts"],
      verbose: true,
    },
  },
  namedAccounts: {
    deployer: 0,
  },
} as HardhatUserConfig;
