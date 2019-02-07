const FC = artifacts.require("./Forecast.sol");

contract('Forecast', ([master, creator, voter_1, voter_2]) => {
	let quiz;

	beforeEach('setup contract', async() => {
		quiz = await(Quiz.new(
			"Who will be the president", 
			3, 
			400,
			web3.utils.toWei('0.01','ether'),
			{ from: creator }
		));
	});

	it('has a creator', async () => {
		assert.equal(await quiz.creator(), creator)
	});

/*	it('is avaliable for funds from creator only', async() => {
		try {
			await quiz.sendTransaction({
			from: voter_2,
			value: 1e+6
			});
			assert.fail();
		} catch (err) {
				assert(err.toString().includes("creator"), err.toString());
				await quiz.sendTransaction({
					from: creator,
					value: 1e+18
				});
			}

		let quizAddress = await quiz.address
		assert.equal(await web3.eth.getBalance(quizAddress), 1e+18);
	});
*/
	it('assigns description correctly', async() => {
		await quiz.assignDescription(0, "Putin");
		const op = await quiz.options(0);
		assert.equal(op.text, "Putin");
	});

	it('doesn`t allow creator to throw votes', async() => {
		try {
			await quiz.throwVote(0, {
				from: creator
			})
			assert.fail();
		} catch (err) {
			assert(err.toString().includes('Creator'), err.toString())
		}
	});

	it('proceeds the whole quiz', async() => {
		await quiz.sendTransaction({
					from: creator,
					value: 1e+18
			});


		const initialBalance = 
			await web3.eth.getBalance(voter_3);
		await quiz.throwVote(0, { from: voter });
		await quiz.throwVote(1, { from: voter_2 });
		await quiz.throwVote(0, { from: voter_3 });

		await quiz.finish({ from: creator });

		let op = await quiz.options(0);

		const overallBalance = 
			await web3.eth.getBalance(voter_3);
		assert(await quiz.WINNING_OPTION() == op.text);
		console.log("Initial Balance:", web3.utils.fromWei(initialBalance.toString(), 'ether'));
		console.log("Overall balance:", web3.utils.fromWei(overallBalance.toString(), 'ether'));
		assert(overallBalance > initialBalance);

		const deviation = web3.utils.toWei('0.00004', 'ether');

		console.log(web3.utils.fromWei((overallBalance - initialBalance).toString(), 'ether'))
		
		const rew = web3.utils.fromWei(await quiz.REWARD(), 'ether')
		console.log("Reward:", rew)
		console.log("Creator balance:", await web3.eth.getBalance(creator))
	});

})

	