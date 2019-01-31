const getCurrentTime =  () => {
	new Promise(resolve => {
		web3.eth.getBlock("latest")
			.then(block => {
				resolve(block.timestamp)
			});
	});
}

Object.assign(exports, {
	getCurrentTime
})