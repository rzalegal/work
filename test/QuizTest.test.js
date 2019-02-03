const Quiz = artifacts.require("./Quiz_Time_Bounded.sol");

contract('Quiz', ([creator, voter, voter_2, voter_3]) => {
	let quiz;

	beforeEach('setup contract', async() => {
		quiz = await(Quiz.new(
			"Who will be the president", 
			3, 
			400,
			web3.utils.toWei('1','ether'),
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

		console.log(await web3.eth.getBalance(await quiz.address))

		const initialBalance = 
			web3.utils.fromWei(await web3.eth.getBalance(voter_3),'ether');
		await quiz.throwVote(0, { from: voter });
		await quiz.throwVote(1, { from: voter_2 });
		await quiz.throwVote(0, { from: voter_3 });

		await quiz.finish({ from: creator });

		let op = await quiz.options(0);

		const overallBalance = 
			web3.utils.fromWei(await web3.eth.getBalance(voter_3), 'ether');
		assert(await quiz.WINNING_OPTION() == op.text);
		console.log(initialBalance);
		console.log(overallBalance)
		const rew = await quiz.REWARD()
		console.log(rew.toString())
	});

})

	