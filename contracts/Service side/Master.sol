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
	returns(Quiz_Time_Bounded)
	{
		address TB_address = new Quiz_Time_Bounded(_for, _title, _duration, _maxReward);
		TB_Quiz[TB_address] = Quiz_Time_Bounded(TB_address);

		return Quiz_Time_Bounded(TB_address);
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
	returns(Quiz_Person_Limited)
	{
		address PL_address = new Quiz_Person_Limited(_for, _title, _maxUsers, _reward);
		PL_Quiz[PL_address] = Quiz_Person_Limited(PL_address);

		return Quiz_Person_Limited(PL_address);
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
	returns(Forecast)
	{
		address FC_address = new Forecast(_for, _title, _duration, _reward);
		FCast[FC_address] = Forecast(FC_address);

		return Forecast(FC_address);
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