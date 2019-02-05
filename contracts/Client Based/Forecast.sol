pragma solidity ^0.4.24;
import "./Judgement.sol";
contract Forecast {

//ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ

	bool public FINISHED;				// Shows whether the quiz is opened/closed;
	bool public JudgementApplied;		// Shows if there was a court-round on the forecast;
	
	string public TITLE; 

    uint256 public beginTime;			//	Quiz start time (block timestamp at the start)
    uint256 public endTime;				//	Quiz finish time ("beginTime" + "duration" user input in the constructor)

    uint256 public REWARD_FUNDS;		//	All the funds to be splitted between participants as a reward
    uint256 public REWARD;				//	Dynamically calculated reward based on PARTICIPANTS.length
    uint256 public MAX_REWARD;
    
    string public WINNING_OPTION;      	//  Текст варианта, набравшего наибольшее количество голосов
    uint256 public WINNING_OPTION_ID;
    
    address public judgesAddress;


    address[] public PARTICIPANTS;

    //	Структура пользователя: голосовал ли ранее (да/нет), эл.почта, выбранный вариант ответа (номер)
	struct User {	
	    bool already;
		string email;
		uint256 choice;
	}

	//	Структура варианта ответа (опции): текстовое описание, число проголосовавших "За"
	struct Option {
		bool descripted;
		string text;
		address[] voters;
	}

	//	Адрес создателя опроса в сети Ethereum 
	//	(определяется непосредственно при создании контракта опроса)
	address public creator;

	// Соответствие между адресами в сети Ethereum и Пользователями опроса
	mapping (address => User) public users;

	//	Массив вариантов ответа
	mapping (uint256 => Option) public options;

//ФУНКЦИОНАЛЬНАЯ ЧАСТЬ

	//	Классический модификатор проверки исполнителя функции:
	//	Серия выплат может быть инициирована только с контракта создателя опроса
	modifier isCreator() {
		require(creator == msg.sender, "For creator uses only");
		_;
	}

	//	Модификатор функции, проверяющий, проходит ли опрос до сих пор
	modifier still_on() {
	    require(now < endTime && !FINISHED, "Quiz is over");
	    _;
	}
	
	//	Модификатор проверки двойного голосования: 
	//	пользователь может обратиться к throwVote лишь один раз
	modifier no_double_vote() {
	    User storage u = users[msg.sender];
	    require(!u.already, "Can`t vote twice");
	    _;
	}
	
	//	Модификатор проверки адреса на наличие исполняемого кода:
	//	Нельзя допустить попадания в список участников АККАУНТОВ-КОНТРАКТОВ,
	//	поскольку именно при помощи последних могут быть произведены попытки взлома
	modifier not_contract() {
		require(!isContract(msg.sender), "Contract injection detected");
		_;
	}
	
	//	Конструктор контракта, создающий опрос с определенным количеством варианта
	constructor
	(
		string _title, 
		uint256 duration, 
		uint256 _reward
	) 
	public
	payable 
	{
	    require(!isContract(msg.sender));
	    require(msg.value > 0, "Creator is to fullfill reward funds");
	    beginTime = now;
	    endTime = beginTime + duration;
	    creator = msg.sender;
	    TITLE = _title;
	    MAX_REWARD = _reward;
	    REWARD_FUNDS = msg.value;

	    emit Forecast_Created(TITLE, creator, beginTime, duration);	
	}
	
	//	Функция отправки голоса за определенный вариант (номер)
	function throwVote(uint256 _choice) 
	public
	not_contract
	still_on
	no_double_vote
	{
		require(creator != msg.sender, "Creator can`t throw votes!");
		require(options[_choice].descripted, "Option must be descripted firstly!");
		User storage u = users[msg.sender];
		PARTICIPANTS.push(msg.sender);
		REWARD = REWARD_FUNDS / PARTICIPANTS.length;
	    u.already = true;
	    options[_choice].voters.push(msg.sender);
	    u.choice = _choice;
	}


	function finish() public isCreator {
		FINISHED = true;
	}

	function createJudgement(uint256 _numJudges, uint256 _reward, uint256 _duration) public isCreator {
		require(FINISHED, "Judgement cannot be created until the forecast expired");
		judgesAddress = new Judgement(msg.sender, TITLE, _numJudges, _reward, _duration);
	}

	function applyJudgement() public isCreator {
		Judgement judge = Judgement(judgesAddress);
		require(judge.FINISHED(), "Judgement cannot be applied until consensus reached or court ");
		WINNING_OPTION_ID = judge.WINNING_OPTION_ID();
		JudgementApplied = true;
	}


	//	Проведение выплат участникам
	function payout() public not_contract returns (bool success) {
		//	Если размер награды превышает максимальный, выплачивается 
		//	установленная создателем максимальная награда
		require(JudgementApplied, "Payout may be proceeded after Judgement only");
		if (REWARD > MAX_REWARD)
			REWARD = MAX_REWARD;

		for (uint256 i = 0; i < options[WINNING_OPTION_ID].voters.length; i++) {
			options[WINNING_OPTION_ID].voters[i].transfer(REWARD);
		}
		// Остатки средств по контракту отправляются создателю контракта
		creator.transfer(address(this).balance);
		emit Payout(TITLE, REWARD, PARTICIPANTS);	
		return true;
	}
	
	//	Вспомогательная функция описания вариантов ответов (номер -> описание)
	//	(Нужна ввиду отсутствия поддержки многомерных динамических массивов в Solidity,
	//	коим и является массив строк)
	function assignDescription(uint256 _no, string memory _text) 
	public 
	isCreator 
	{
		require(!options[_no].descripted, "Option is descripted already");
	    options[_no].text = _text;
	    options[_no].descripted = true;
	    emit Option_Assigned(TITLE, _no, _text);
	}

	//	Функция проверки адреса, используемая в модификаторе "not_contract()":
	//	Если объем исполняемого кода адреса больше нуля, значит отправитель - контракт (жулик)
	function isContract(address addr) private view returns (bool) {
  		uint size;
  		assembly 
  		{ 
  			size := extcodesize(addr)
  		}
  		return size > 0;
	}

	event Forecast_Created(string title, address creator, uint256 timestamp, uint256 duration);
	event Option_Assigned(string title, uint256 no, string text);
	event Payout(string title, uint256 amount, address[] participants);
	event Forecast_Finished(string title, string winningOption, uint256 timestamp);
}
