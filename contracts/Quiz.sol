pragma solidity ^0.4.24;

contract Quiz {

//ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ

	bool public FINISHED;		// Shows whether the quiz is opened/closed;
	
	string	public	TITLE; 

    uint256 public beginTime;	//	Quiz start time (block timestamp at the start)
    uint256 public endTIme;		//	Quiz finish time ("beginTime" + "duration" user input in the constructor)
    uint256 public PARTICIPANTS;//	Total number of quiz participants (use in forward to calculate the real-time REWARD value)

    uint256 REWARD_FUNDS;		//	All the funds to be splitted between participants as a reward
    uint256 REWARD;				//	Dynamically calculated reward based on PARTICIPANTS.length

    uint256 TX_FUNDS; 			//	Transaction fee payments funds (50% of this.balance at most)
    							//	(If not empty by the quiz finish moment, the funds return to the creator)

    uint256 TX_SPENT;

    uint256 MAX_REWARD;			// 	Максимальное вознаграждение за участие в опросе (устанавливается создателем опроса)

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

	//	Массив адресов участников опроса в сети Ethereum 
	//	(впоследствии используется при для распределения вознаграждений)
	address[] USER_LIST;

	// Соответствие между адресами в сети Ethereum и Пользователями опроса
	mapping (address => User) users;

	//	Массив вариантов ответа
	Option[] options;

//ФУНКЦИОНАЛЬНАЯ ЧАСТЬ

	modifier gas_refund()
    {
    	if (TX_SPENT > TX_FUNDS)
    		finish();

        uint256 startGas = gasleft();
        _;
        uint256 endGas = gasleft();
        uint256 usedGas = startGas - endGas;
        uint256 gasPrice = usedGas * tx.gasprice;
        msg.sender.transfer(gasPrice);
    }

	//	Классический модификатор проверки исполнителя функции:
	//	Серия выплат может быть инициирована только с контракта создателя опроса
	modifier isCreator() {
		require(creator == msg.sender, "For creator uses only");
		_;
	}

	//	Модификатор функции, проверяющий, проходит ли опрос до сих пор
	modifier still_on() {
	    require(now < endTIme && !FINISHED, "Quiz is over");
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

	//	Fallback-функция, отвечающая за прием средств контракта
	function() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");
        TX_FUNDS = REWARD_FUNDS = msg.value / 2;
	}

	//	Конструктор контракта, создающий опрос с определенным количеством варианта
	constructor(uint256 _numOptions, uint256 duration) public {
	    require(!isContract(msg.sender));
	    beginTime = now;
	    endTIme = beginTime + duration;
	    creator = msg.sender;

	    for (uint256 i = 0; i < _numOptions; i++) {
	        options.push(Option({
	            text: '',
	            totalVotes: 0
	        }));
	    }	
	}
	
	//	Функция отправки голоса за определенный вариант (номер)
	function throwVote(uint256 _choice) 
	public
	payable
	not_contract
	still_on
	no_double_vote
	gas_refund
	{
		User storage u = users[msg.sender];
		PARTICIPANTS += 1;
		REWARD = REWARD_FUNDS / PARTICIPANTS;
	    u.already = true;
	    options[_choice].totalVotes += 1;
	    u.choice = _choice;
	}
	
	//	Функция определения варианта-победителя 
	//	(к распределению средств отношения не имеет, нужна только заказчику опроса)
	function returnWinner() public view returns(string memory) {
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

	function finish() public {
		FINISHED = true;
		payout();
	}

	//	Проведение выплат участникам
	function payout() internal returns (bool success) {
		//	Если размер награды превышает максимальный, выплачивается 
		//	установленная создателем максимальная награда
		if (REWARD > MAX_REWARD)
			REWARD = MAX_REWARD;

		for (uint256 i = 0; i < USER_LIST.length; i++) {
			USER_LIST[i].transfer(REWARD);
		}
		// Остатки средств по контракту отправляются создателю контракта
		creator.transfer(address(this).balance);
		
		return true;
	}
	
	//	Вспомогательная функция описания вариантов ответов (номер -> описание)
	//	(Нужна ввиду отсутствия поддержки многомерных динамических массивов в Solidity,
	//	коим и является массив строк)
	function assignDescription(uint256 _no, string memory _text) public {
	    options[_no].text = _text;
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
}
