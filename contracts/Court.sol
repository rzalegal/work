pragma solidity ^0.4.24;
import "./Forecast.sol";
contract Court {

//ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ

	bool public FINISHED;		// Shows whether the quiz is opened/closed;
	bool public ACTIVE;
	string public TITLE; 
    uint256 public beginTime;	//	Quiz start time (block timestamp at the start)
    uint256 public REWARD;		//	Dynamically calculated reward based on PARTICIPANTS.length
    uint256 public MAX_USERS;	//  Maximal quiantity of judges specified by creator	

    Forecast forecast;

    string public WINNING_OPTION;      //  Текст варианта, набравшего наибольшее количество голосов

    address[] public PARTICIPANTS;

    //	Структура пользователя: голосовал ли ранее (да/нет), эл.почта, выбранный вариант ответа (номер)
	struct Judge {	
	    bool already;
		string email;
		uint256 choice;
	}

	//	Структура варианта ответа (опции): текстовое описание, число проголосовавших "За"
	struct Option {
		string text;
		uint256 totalVotes;
		uint256 percent;
		address[] voters;
		bool descripted;
	}

	//	Адрес создателя опроса в сети Ethereum 
	//	(определяется непосредственно при создании контракта опроса)
	address public creator;

	// Соответствие между адресами в сети Ethereum и Пользователями опроса
	mapping (address => Judge) judges;

	//	Массив вариантов ответа
	mapping (uint256 => Option) options;

//ФУНКЦИОНАЛЬНАЯ ЧАСТЬ

	//	Классический модификатор проверки исполнителя функции:
	//	Серия выплат может быть инициирована только с контракта создателя опроса
	modifier isCreator() {
		require(creator == msg.sender, "For creator uses only");
		_;
	}

	//	Модификатор функции, проверяющий, проходит ли опрос до сих пор
	modifier still_on() {
	    require(!FINISHED && ACTIVE, "Quiz is over");
	    _;
	}
	
	//	Модификатор проверки двойного голосования: 
	//	пользователь может обратиться к throwVote лишь один раз
	modifier no_double_vote() {
	    Judge storage u = judges[msg.sender];
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
	    address _creator,
		string _title, 
		uint256 _maxJudges, 
		uint256 _reward
	) 
	public
	payable 
	{
	    require(msg.value > 0, "Creator is to fullfill reward funds");
	    beginTime = now;
	    creator = _creator;
	    TITLE = _title;
	    REWARD = _reward;
	    MAX_USERS = _maxJudges;

	    emit Court_Created(TITLE, creator, beginTime, MAX_USERS);	
	}
	
	//	Функция отправки голоса за определенный вариант (номер)
	function throwVote(uint256 _choice) 
	public
	payable
	not_contract
	still_on
	no_double_vote
	contract_has_funds
	{
		require(creator != msg.sender, "Creator can`t throw votes!");
		require(PARTICIPANTS.length < MAX_USERS, "Maximum judges cap reached");
		require(options[_choice].descripted, "Option must be descripted firstly!");

		Judge storage u = judges[msg.sender];
		Option storage op = options[_choice];

		PARTICIPANTS.push(msg.sender);

	    u.already = true;
	    u.choice = _choice;

	    op.totalVotes += 1;
	    op.percent = op.totalVotes / PARTICIPANTS.length * 100;
	}

	function finish() isCreator public {
		FINISHED = true;
		uint256 max;
	    uint256 winner;
	    for (uint256 i = 0; i < PARTICIPANTS.length; i++) {
	        if (options[i].totalVotes > max) {
	            max = options[i].totalVotes;
	            winner = i;
	        }
	    }
	    require(options[winner].percent >= 95, "Consensus not reached. Delegating on admin");
	    WINNING_OPTION = options[winner].text;
	    emit Court_Finished(TITLE, WINNING_OPTION, now);
	}
	
	//	Вспомогательная функция описания вариантов ответов (номер -> описание)
	//	(Нужна ввиду отсутствия поддержки многомерных динамических массивов в Solidity,
	//	коим и является массив строк)
	function assignDescription(uint256 _no, string memory _text) 
	public 
	isCreator 
	{
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

	function activate(address _addr) public isCreator {
		forecast = Forecast(_addr);
		require(forecast.FINISHED());
		ACTIVE = true;
	}

	event Court_Created(string _title, address _creator, uint256 _timestamp, uint256 _duration);
	event Option_Assigned(string _courtTitle, uint256 _no, string _text);
	event Payout(string _courtTitle, uint256 _amount, address[] _participants);
	event Court_Finished(string _title, string _winningOption, uint256 timestamp);
}
