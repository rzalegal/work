const testContract = artifacts.require("Quiz_Person_Limited_cli");
const thrown = require('../utils');

contract('Quiz Person Limited', ([creator, voter_1, voter_2, voter_3]) => {
	let test;

	beforeEach('setup contract', async() => {
		test = await testContract.new(
			"Who knocks?", 
			2, 
			1000000, 
			{
				from: creator, 
				value: (10**18).toString()
			});

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

	it('halts after maxUsers reached', async() => {
		try {
			await test.throwVote(1, { from: voter_1 });
			await test.throwVote(1, { from: voter_2 });
			await test.throwVote(2, { from: voter_3 });
			assert.fail()
		} catch (e) {
			thrown(e, "reached");
		}
	});
})

