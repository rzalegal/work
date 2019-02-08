const testContract = artifacts.require("Forecast_cli");
const Judger = artifacts.require("Judgement_cli");
const thrown = require('../utils');

contract('Forecast', ([creator, voter_1, voter_2, judge_1, judge_2, judge_3]) => {
	let test;

	beforeEach('setup contract', async() => {
		test = await testContract.new("who knocks?", 2, 1000000, 
			{
				from: creator, 
				value: (10**18).toString()
			}
		);

		for (let i = 0; i < 3; i++) {
		    await test.assignDescription(i, `${i}th option to choose`)
		}
	});

	it('has a creator', async() => {
	    assert.equal(await test.creator(), creator, "creator addresses do not match")
	});

	it('doesn`t allow another contract to call the functions', async() => {
	    try {
	        let injector = await test.address;
	        await test.throwVote(1, {from: injector});
	        assert.fail()
	    } catch (e) {
	        thrown(e, "injection");
	    }
	});

	it('allow users to throw votes only once', async() => {
	   	try {
	        await test.throwVote(0, { from: voter_1 })
	        await test.throwVote(0, { from: voter_1 })
	        assert.fail()
	   } catch (e) {
	        thrown(e, "twice");
	   }
	});

	it('doesn`t allow creator to send votes', async() => {
	    try {
	        await test.throwVote(1, { from: creator })
	        assert.fail()
	    } catch (e) {
	        thrown(e, "Creator");
	    }
	});

	it('provides judgement round', async() => {
		await test.throwVote(0, { from: voter_1 });
	    await test.throwVote(0, { from: voter_2 });

	    try {
	    	await test.finish({ from: voter_1 });
	    } catch (e) {
	    	thrown(e, "uses");
	    }
	    await test.finish({ from: creator });
	    await test.createJudgement(2, 10, 1000000, { from: creator });

		

		    for (let i = 0; i < 3; i++) {
			    await court.assignDescription(i, `${i}th option to choose`);
			}
		try {
			await test.applyJudgement({ from: creator });
		} catch (e) {
			thrown(e, "consensus");
		}
			await court.throwVote(0, { from: judge_1 });
			await court.throwVote(0, { from: judge_2 });
			await court.throwVote(0, { from: judge_3 });

			await court.finish({ from: creator });

			await test.applyJudgement({ from: creator });
			await test.finish({ creator });
	    
	});
});

