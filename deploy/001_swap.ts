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
  const erc1 = await deploy("ERC20", {
    from: deployer,
    args: ["test1", "t1"],
    log: true,
  });
  const erc2 = await deploy("ERC20", {
    from: deployer,
    args: ["test2", "t2"],
    log: true,
  });

  const args = [[erc1.address, erc2.address], ["18", "18"], "test pool", "tp1"];
  await deploy("Swap", {
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
