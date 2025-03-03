import asyncio

cdef class StorageClient :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
		self.connected = False
		self.reader = None
		self.writer = None
		self.received = None

	def send(self, message: bytes) :
		return asyncio.run(self.request(message, self.handleRequest))

	async def request(self, message: bytes, handle) :
		if not self.connected :
			self.reader, self.writer = await asyncio.open_connection(self.host, self.port)
			self.connected = True
		await handle(message, self.writer, self.reader)
	
	async def handleRequest(self, message: bytes, writer, reader) :
		writer.write(message)
		await writer.drain()
		self.received = await reader.read(1 << 16)
		writer.close()
		await writer.wait_closed()
		self.connected = False
		print("Connection Closed")
