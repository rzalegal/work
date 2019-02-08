pragma solidity ^0.4.24;

contract Quiz_Time_Bounded_cli {

//ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ

	bool public FINISHED;		// Shows whether the quiz is opened/closed;
	
	string public TITLE;
    string public WINNING_OPTION;      //  Текст варианта, набравшего наибольшее количество голосов 

    uint256 public beginTime;	//	Quiz start time (block timestamp at the start)
    uint256 public endTime;		//	Quiz finish time ("beginTime" + "duration" user input in the constructor)

    uint256 public REWARD_FUNDS;		//	All the funds to be splitted between participants as a reward
    uint256 public REWARD;				//	Dynamically calculated reward based on PARTICIPANTS.length

    uint256 public MAX_REWARD;			// 	Максимальное вознаграждение за участие в опросе (устанавливается создателем опроса)
    uint256 public NUM_OPTIONS;

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
		uint256 _maxReward
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
	    MAX_REWARD = _maxReward;
	    REWARD_FUNDS = msg.value / 2;

	    emit Quiz_Created(TITLE, "Person Limited", creator, beginTime, duration);	
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

		PARTICIPANTS.push(msg.sender);

		User storage u = users[msg.sender];
		u.already = true;
		u.choice = _choice;
	    
	    options[_choice].totalVotes += 1;

	    REWARD = REWARD_FUNDS / PARTICIPANTS.length;
	}

	function finish() isCreator public {
		FINISHED = true;

		uint256 max;
	    uint256 winner;

	    for (uint256 i = 0; i < NUM_OPTIONS; i++) {
	        if (options[i].totalVotes > max) {
	            max = options[i].totalVotes;
	            winner = i;
	        }
	    }

	    WINNING_OPTION = options[winner].text;

	    emit Quiz_Finished("Creator finished the quiz", TITLE, WINNING_OPTION, endTime);
	    payout();
	}

	//	Проведение выплат участникам
	function payout() internal isCreator returns (bool success) {
		//	Если размер награды превышает максимальный, выплачивается 
		//	установленная создателем максимальная награда
		if (REWARD > MAX_REWARD)
			REWARD = MAX_REWARD;

		for (uint256 i = 0; i < PARTICIPANTS.length; i++) {
			PARTICIPANTS[i].transfer(REWARD);
		}
		// Остатки средств по контракту отправляются создателю контракта
		creator.transfer(address(this).balance);
		emit Payout(REWARD, PARTICIPANTS, now);
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
	    NUM_OPTIONS += 1;
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

	event Quiz_Created(
		string title, 
		string _type, 
		address creator, 
		uint256 timestamp, 
		uint256 duration
	);
	
	event Quiz_Finished(
		string reason, 
		string title, 
		string winningOption, 
		uint256 timestamp
	);

	event Option_Assigned(string title, uint256 no, string text);
	event Payout(uint256 amount, address[] participants, uint256 timestamp);
}
