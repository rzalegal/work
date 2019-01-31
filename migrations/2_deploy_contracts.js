var Quiz = artifacts.require("./Quiz.sol");

module.exports = function(deployer) {
	deployer.deploy(Quiz, 3, 400);
};