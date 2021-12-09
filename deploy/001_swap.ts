import { DeployFunction } from "hardhat-deploy/types";

const deployMinima: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  getChainId,
  getUnnamedAccounts,
}) {
  // await hre.run('compile');
  const { deployer } = await getNamedAccounts();
  const { deploy } = deployments;
  const SafeERC20 = await deploy("SafeERC20", { from: deployer, log: true });
  const SafeMath = await deploy("SafeMath", { from: deployer, log: true });

  console.log(`Deploying from ${deployer}`);
  // const erc1 = await deploy("ERC20", {
  //   from: deployer,
  //   args: ["test1", "t1"],
  //   log: true,
  // });
  // const erc2 = await deploy("ERC20", {
  //   from: deployer,
  //   args: ["test2", "t2"],
  //   log: true,
  // });
  const tokens = [
    "0xE919F65739c26a42616b7b8eedC6b5524d1e3aC4",
    "0x122013fd7dF1C6F636a5bb8f03108E876548b455",
  ];

  const args = [tokens, ["18", "18"], "OpenSum wETH v1/v2 LP", "OSlp"];
  const deployment = await deploy("OpenSumSwap", {
    from: deployer,
    args,
    log: true,
    libraries: {
      SafeERC20: SafeERC20.address,
      SafeMath: SafeMath.address,
    },
  });
  console.log(`Deployed at ${deployment.address}`);
};

export default deployMinima;
deployMinima.id = "deploy_dexes";
deployMinima.tags = ["Dexes"];
