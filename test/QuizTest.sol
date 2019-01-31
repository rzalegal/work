pragma solidity ^0.4.24;
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Quiz.sol";

contract QuizTest {
	function globalsSettingTest() public {
		Quiz q = Quiz(DeployedAddresses.Quiz());

		uint256 _numOptions = q.getOptionsCount();

		Assert.equal(_numOptions, 3, "Must be 3 options exaclty");
	}

	function hello() public pure {
		Assert.equal(3,3,"Equal");
	}
}