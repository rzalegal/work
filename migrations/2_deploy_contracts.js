var Quiz_Time_Bounded = artifacts.require("./Quiz_Time_Bounded.sol");
var Quiz_Person_Limited = artifacts.require("./Quiz_Person_Limited.sol");

module.exports = function(deployer) {
	deployer.deploy(Quiz_Time_Bounded, "Who will be the president", 3, 400, web3.utils.toWei('0.1','ether'));
	deployer.deploy(Quiz_Person_Limited);
};