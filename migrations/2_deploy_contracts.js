const AaveSushi = artifacts.require("AaveSushi");

module.exports = function(deployer, network, accounts) {
  console.log(accounts);
  deployer.deploy(AaveSushi);
};