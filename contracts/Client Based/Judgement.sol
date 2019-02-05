pragma solidity ^0.4.24;
import "./Forecast.sol";
contract Judgement {

//ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ

	bool public FINISHED;		// Shows whether the quiz is opened/closed;

	string public TITLE; 

    uint256 public beginTime;	//	Quiz start time (block timestamp at the start)
    uint256 public endTime;
    
    uint256 public REWARD;		//	Dynamically calculated reward based on JUDGES.length
    uint256 public MAX_USERS;	//  Maximal quiantity of judges specified by creator	

    Forecast forecast;

    uint256 public WINNING_OPTION_ID;      //  Текст варианта, набравшего наибольшее количество голосов
    string public WINNING_OPTION;

    address FORECAST_ON_COURT;

    address[] public JUDGES;

    //	Структура пользователя: голосовал ли ранее (да/нет), эл.почта, выбранный вариант ответа (номер)
	struct Judge {	
	    bool already;
		string email;
		uint256 choice;
	}

	//	Структура варианта ответа (опции): текстовое описание, число проголосовавших "За"
	struct Option {
		string text;
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
	    require(!FINISHED && now < endTime);
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
		uint256 _reward,
		uint256 _duration
	) 
	public
	payable 
	{
	    beginTime = now;
	    endTime = beginTime + _duration;
	    creator = _creator;
	    FORECAST_ON_COURT = msg.sender;
	    TITLE = _title;
	    REWARD = _reward;
	    MAX_USERS = _maxJudges;

	    emit Judgement_Created(
	    	FORECAST_ON_COURT ,
	    	TITLE,
	    	beginTime, 
	    	creator,
	    	MAX_USERS
	    );	
	}
	
	//	Функция отправки голоса за определенный вариант (номер)
	function throwVote(uint256 _choice) 
	public
	not_contract
	still_on
	no_double_vote
	{
		require(creator != msg.sender, "Creator can`t throw votes!");
		require(JUDGES.length < MAX_USERS, "Maximum judges cap reached");
		require(options[_choice].descripted, "Option must be descripted firstly!");

		Judge storage u = judges[msg.sender];
		Option storage op = options[_choice];

		JUDGES.push(msg.sender);

	    u.already = true;
	    u.choice = _choice;

	    op.voters.push(msg.sender);
	    op.percent = op.voters.length / JUDGES.length * 100;
	}

	function finish() isCreator public {
		FINISHED = true;
		uint256 max;
	    uint256 winner;
	    for (uint256 i = 0; i < JUDGES.length; i++) {
	        if (options[i].voters.length > max) {
	            max = options[i].voters.length;
	            winner = i;
	        }
	        WINNING_OPTION_ID = winner;
	        WINNING_OPTION = options[WINNING_OPTION_ID].text;
	    }
	    if (options[winner].percent >= 95) {
	    	emit Judgement_Finished(
	    	    "No Consensus between the judges reached",
	    	    FORECAST_ON_COURT,
	    	    options[WINNING_OPTION_ID].text,
	    	    now
	    	);
	    	revert("Consensus not reached. Delegating on admin");
	    }
	    emit Judgement_Finished(
	        "Consensus reached.", 
	        FORECAST_ON_COURT, 
	        options[WINNING_OPTION_ID].text,
	        now
	    );
        
        address[] storage guessed = options[WINNING_OPTION_ID].voters ;
	    for (i = 0; i < guessed.length; i++) {
			options[WINNING_OPTION_ID].voters[i].transfer(REWARD);
		}
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

	event Judgement_Created(
		address Forecast_on_Court, 
		string title, 
		uint256 timestamp, 
		address Creator, 
		uint256 reward
	);
	
	event Judgement_Finished(
		string reason, 
		address Forecast_on_Court,
		string winning_Option,
		uint256 timestamp
	);
	
	event Payout(string title, uint256 amount, address[] judges, uint256 timestamp);
}
