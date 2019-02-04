pragma solidity ^0.4.24;

contract Quiz_Person_Limited {

//ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ

	bool public FINISHED;		// Shows whether the quiz is opened/closed;
	string public TITLE; 
    uint256 public beginTime;	//	Quiz start time (block timestamp at the start)
    uint256 public REWARD;		//	Dynamically calculated reward based on PARTICIPANTS.length
    uint256 public MAX_USERS;	//  Maximal quiantity of users specified by creator	

    string public WINNING_OPTION;      //  Текст варианта, набравшего наибольшее количество голосов

    address[] public PARTICIPANTS;

    //	Структура пользователя: голосовал ли ранее (да/нет), эл.почта, выбранный вариант ответа (номер)
	struct User {	
	    bool already;
		string email;
		uint256 choice;
	}

	//	Структура варианта ответа (опции): текстовое описание, число проголосовавших "За"
	struct Option {
		string text;
		uint256 totalVotes;
		bool descripted;
	}

	//	Адрес создателя опроса в сети Ethereum 
	//	(определяется непосредственно при создании контракта опроса)
	address public creator;

	// Соответствие между адресами в сети Ethereum и Пользователями опроса
	mapping (address => User) users;

	//	Массив вариантов ответа
	Option[] public options;

//ФУНКЦИОНАЛЬНАЯ ЧАСТЬ

	//	Классический модификатор проверки исполнителя функции:
	//	Серия выплат может быть инициирована только с контракта создателя опроса
	modifier isCreator() {
		require(creator == msg.sender, "For creator uses only");
		_;
	}

	//	Модификатор функции, проверяющий, проходит ли опрос до сих пор
	modifier still_on() {
	    require(address(this).balance > REWARD && !FINISHED, "Quiz is over");
	    _;
	}
	
	//	Модификатор проверки двойного голосования: 
	//	пользователь может обратиться к throwVote лишь один раз
	modifier no_double_vote() {
	    User storage u = users[msg.sender];
	    require(!u.already, "Can`t vote twice");
	    _;
	}

	//	Функция не будет вызвана, если на контракте отсутствуют средства
	modifier contract_has_funds() {
		require(address(this).balance > 0);
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
		uint256 _options,
		uint256 _maxUsers, 
		uint256 _reward
	) 
	public
	payable 
	{
	    require(!isContract(msg.sender));
	    require(msg.value > 0, "Creator is to fullfill reward funds");
	    beginTime = now;
	    creator = msg.sender;
	    TITLE = _title;
	    REWARD = _reward;
	    MAX_USERS = _maxUsers;

	    for (uint256 i = 0; i < _options; i++) {
	        options.push(Option({
	            text: '',
	            totalVotes: 0,
	            descripted: false
	        }));
	    }

	    emit Quiz_Created(TITLE, creator, beginTime, MAX_USERS);	
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
		require(PARTICIPANTS.length < MAX_USERS, "Maximum users cap reached");
		require(options[_choice].descripted, "Option must be descripted firsty!");
		User storage u = users[msg.sender];
		PARTICIPANTS.push(msg.sender);
	    u.already = true;
	    options[_choice].totalVotes += 1;
	    u.choice = _choice;
	    msg.sender.transfer(REWARD);
	}

	function finish() isCreator public {
		FINISHED = true;
		uint256 max;
	    uint256 winner;
	    for (uint256 i = 0; i < options.length; i++) {
	        if (options[i].totalVotes > max) {
	            max = options[i].totalVotes;
	            winner = i;
	        }
	    }
	    WINNING_OPTION = options[winner].text;
	    emit Quiz_Finished(TITLE, WINNING_OPTION, now);
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

	event Quiz_Created(string _title, address _creator, uint256 _timestamp, uint256 _duration);
	event Option_Assigned(string _quizTitle, uint256 _no, string _text);
	event Payout(string _quizTitle, uint256 _amount, address[] _participants);
	event Quiz_Finished(string _title, string _winningOption, uint256 timestamp);
}
