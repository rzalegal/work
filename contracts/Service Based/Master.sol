pragma solidity ^0.4.24;
import "./Forecast.sol";
import "./Quiz_Time_Bounded.sol";
import "./Quiz_Person_Limited.sol";

contract Master {

//	Адрес мастер-аккаунта с транзакционным эфиром
	address master;

//	Соответствия адресов типовым контрактам
	mapping(address => Quiz_Time_Bounded) 	TB_Quiz;
	mapping(address => Quiz_Person_Limited)	PL_Quiz;
	mapping(address => Forecast) 			FCast;	

//	Модификатор функции: вызов возможен только с мастер-аккаунта
	modifier isMaster() {
		require(msg.sender == master);
		_;
	}

	modifier exists(address _addr) {
		require(
			TB_Quiz[_addr] ||
			PL_Quiz[_addr] ||
			FCast[_addr],
			"Contract doesn`t exist. Use `create` master-methods");
		_;
	}

//	Constructor assigns msg.sender to master and checks
//	if the caller was a contract
	constructor() public {
		require(!isContract(msg.sender));
		master = msg.sender;
	}

//ФУНКЦИОНАЛЬНАЯ ЧАСТЬ

//	Функции создают контракты соответствующих типов
//	и возвращают его адрес для последующего использования	

//	Ограниченный по времени опрос
	function create_TimeBounded_Quiz(
		address _for, 
		string _title, 
		uint256 _duration, 
		uint256 _maxReward
	) 
	public 
	isMaster 
	returns(address)
	{
		address TB_address = new Quiz_Time_Bounded(_for, _title, _duration, _maxReward);
		TB_Quiz[TB_address] = Quiz_Time_Bounded(TB_address);

		return TB_address;
	}

//	Ограниченный по числу участников опрос
	function create_PersonLimited_Quiz(
		address _for,
		string _title,
		uint256 _maxUsers,
		uint256 _reward
	)
	public
	isMaster
	returns(address)
	{
		address PL_address = new Quiz_Person_Limited(_for, _title, _maxUsers, _reward);
		PL_Quiz[PL_address] = Quiz_Person_Limited(PL_address);

		return PL_address;
	}

//	Прогноз
	function create_Forecast(
		address _for,
		string _title,
		uint256 _duration,
		uint256 _reward
	)
	public
	isMaster
	returns(address)
	{
		address FC_address = new Forecast(_for, _title, _duration, _reward);
		FCast[FC_address] = FCast(FC_address);
		return FC_address;
	}

//	Функция голоса от имени пользователя
	function Vote(
		string _contractType, 
		address _contractAddress, 
		address _for,
		uint256 _choice
	)
	public
	isMaster
	exists(_contractAddress)
	{
		if (_contractType == "TB") 
		{
			TB_Quiz[_contractAddress].throwVote(_for, _choice);
		} else if (_contractType == "PL") 
		{
			PL_Quiz[_contractAddress].throwVote(_for, choice);
		} else if (_contractType == "FC")
		{
			FCast[_contractAddress].throwVote(_for, choice);
		} else {
			revert("Incorrect contract type input: `TB`,`PL` or `FC` allowed")
		}  
	}  

//	Вспомогательная функция проверки вызывающего аккаунта
	function isContract(address addr) private view returns(bool) {
		uint256 code;
		assembly 
		{
			code := extcodesize(addr) 
		}
		return code > 0;
	}

}