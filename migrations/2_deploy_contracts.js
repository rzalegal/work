var Quiz = artifacts.require("./Quiz_Time_Bounded.sol");

module.exports = function(deployer) {
	deployer.deploy(Quiz, "Who will be the president", 3, 400, web3.utils.toWei('0.1','ether'));
};