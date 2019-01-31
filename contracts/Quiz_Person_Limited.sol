pragma solidity ^0.4.24;

contract Quiz_Person_Limited {

//ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
	
	bool FINISHED;

	string public TITLE; 

    uint256 REWARD_FUNDS;		//	All the funds to be splitted between participants as a reward
    uint256 REWARD;				//	Dynamically calculated reward based on PARTICIPANTS.length

    uint256 TX_FUNDS; 			//	Transaction fee payments funds (50% of this.balance at most)
    							//	(If not empty by the quiz finish moment, the funds return to the creator)

    uint256 TX_SPENT;

    uint256 REWARD;			// 	Максимальное вознаграждение за участие в опросе (устанавливается создателем опроса)
    string WINNING_OPTION;      //  Текст варианта, набравшего наибольшее количество голосов

    address[] PARTICIPANTS;

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
	}

	//	Адрес создателя опроса в сети Ethereum 
	//	(определяется непосредственно при создании контракта опроса)
	address creator;

	// Соответствие между адресами в сети Ethereum и Пользователями опроса
	mapping (address => User) users;

	//	Массив вариантов ответа
	Option[] options;

//ФУНКЦИОНАЛЬНАЯ ЧАСТЬ

	//	Классический модификатор проверки исполнителя функции:
	//	Серия выплат может быть инициирована только с контракта создателя опроса
	modifier isCreator() {
		require(creator == msg.sender, "For creator uses only");
		_;
	}

	//	Модификатор функции, проверяющий, проходит ли опрос до сих пор
	modifier still_on() {
	    require(address(this).balance > REWARD && !FINISHED);
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

	modifier has_value() {
		require(msg.value > 0):
		_;
	}
	
	//	Fallback-функция, отвечающая за прием средств контракта
	function() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");
        TX_FUNDS = REWARD_FUNDS = msg.value / 2;
	}

	//	Конструктор контракта, создающий опрос с определенным количеством варианта
	constructor(
		string _title, 
		uint256 _numOptions, 
		uint256 _numUsers, 
		uint256 _reward
		) 
	public
	payable 
	{
	    require(!isContract(msg.sender));
	    creator = msg.sender;
	    TITLE = _title;
	    REWARD = _reward;

	    for (uint256 i = 0; i < _numOptions; i++) {
	        options.push(Option({
	            text: '',
	            totalVotes: 0
	        }));
	    }

	    emit Quiz_Created(TITLE, msg.sender, now, _numUsers);	
	}
	
	//	Функция отправки голоса за определенный вариант (номер)
	function throwVote(uint256 _choice) 
	public
	payable
	not_contract
	still_on
	no_double_vote
	has_value
	{
		require(creator != msg.sender);
		User storage u = users[msg.sender];
		PARTICIPANTS.push(msg.sender);
		REWARD = REWARD_FUNDS / PARTICIPANTS.length;
	    u.already = true;
	    options[_choice].totalVotes += 1;
	    u.choice = _choice;
	}
	
	//	Функция определения варианта-победителя 
	//	(к распределению средств отношения не имеет, нужна только заказчику опроса)
	function returnWinner() internal view returns(string memory) {
	    uint256 max;
	    uint256 winner;
	    for (uint256 i = 0; i < options.length; i++) {
	        if (options[i].totalVotes > max) {
	            max = options[i].totalVotes;
	            winner = i;
	        }
	    }
	    return options[winner].text;
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
		payout();
		emit Quiz_Finished(TITLE, WINNING_OPTION, endTIme);
		emit Payout(TITLE, REWARD, PARTICIPANTS);
	}
/*
	//	Проведение выплат участникам
	function payout() internal isCreator returns (bool success) {
		//	Если размер награды превышает максимальный, выплачивается 
		//	установленная создателем максимальная награда
		if (REWARD > REWARD)
			REWARD = REWARD;

		for (uint256 i = 0; i < PARTICIPANTS.length; i++) {
			PARTICIPANTS[i].transfer(REWARD);
		}
		// Остатки средств по контракту отправляются создателю контракта
		creator.transfer(address(this).balance);
		
		return true;
	}
*/	
	//	Вспомогательная функция описания вариантов ответов (номер -> описание)
	//	(Нужна ввиду отсутствия поддержки многомерных динамических массивов в Solidity,
	//	коим и является массив строк)
	function assignDescription(uint256 _no, string memory _text) public {
	    options[_no].text = _text;
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

	event Quiz_Created(string _title, address _creator, uint256 _timestamp, uint256 __numUsers);
	event Option_Assigned(string _quizTitle, uint256 _no, string _text);
	event Payout(string _quizTitle, uint256 _amount, address[] _participants);
	event Quiz_Finished(string _title, string _winningOption, uint256 timestamp);
}
