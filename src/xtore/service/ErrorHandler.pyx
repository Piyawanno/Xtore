import asyncio

cdef class ErrorHandler:
	def __init__(self):
		self.failedData = []

	async def handleError(self, processID: str, message: bytes, host: str, port: int, object tcpFunction):
		try:
			await tcpFunction(processID, message, host, port)
		except (asyncio.TimeoutError, ConnectionRefusedError, ConnectionError) as e:
			print(f"[{processID}]({host}:{port}) >> ERROR {str(e)}")
			self.failedData.append((processID, message, host, port))

	async def resend(self, object tcpFunction):
		if not self.failedData:
			print("No failed records to retry.")
			return

		print("Retrying failed records...")
		cdef list retryQueue = self.failedData.copy()
		self.failedData.clear()

		cdef list tasks = []
		for processID, message, host, port in retryQueue:
			print(f"🔄 Retrying {processID} to {host}:{port}...")
			task = asyncio.create_task(self.handleError(processID, message, host, port, tcpFunction))
			tasks.append(task)

		await asyncio.gather(*tasks)
