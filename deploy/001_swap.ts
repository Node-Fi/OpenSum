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
    "0xBAAB46E28388d2779e6E31Fd00cF0e5Ad95E327B",
    "0xBe50a3013A1c94768A1ABb78c3cB79AB28fc1aCE",
  ];

  const args = [tokens, ["8", "8"], "OpenSum wBTC v1/v2 LP", "OSlp"];
  await deploy("OpenSumSwap", {
    from: deployer,
    args,
    log: true,
    libraries: {
      SafeERC20: SafeERC20.address,
      SafeMath: SafeMath.address,
    },
  });
};

export default deployMinima;
deployMinima.id = "deploy_dexes";
deployMinima.tags = ["Dexes"];
