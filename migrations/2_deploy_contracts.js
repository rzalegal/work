let Forecast_cli = artifacts.require("Forecast_cli");
let Quiz_TB_cli = artifacts.require("Quiz_Time_Bounded_cli");
let Quiz_PL_cli = artifacts.require("Quiz_Person_Limited_cli");
let Judger = artifacts.require("Judgement_cli");

const toWei = n => web3.utils.toWei(n.toString(), 'ether').toString();

module.exports = function(deployer) {
    deployer.deploy(Forecast_cli, "Who will be the president?", 400, 100000000, {value: toWei(0.2) });
    deployer.deploy(Quiz_TB_cli, "Who will be the president?", 3, 100000000, {value: toWei(0.1) });
    deployer.deploy(Quiz_PL_cli, "Who will be the president?", 2, 100000000, {value: toWei(0.1) }); 
    deployer.deploy(Judger, 2, 10, 400000, {value: toWei(0.1) });   
}