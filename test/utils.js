const thrown = (e, expectedContents) => {
	e = e.toString().slice(e.toString().indexOf("given:") + 6);
		
		assert(e.includes(expectedContents.toString()),
		`Message "${e}" does not include expected "${expectedContents}"`);
		
		console.log(`Message "${e}" thrown and includes "${expectedContents}" as expected`);
	}

module.exports = thrown;