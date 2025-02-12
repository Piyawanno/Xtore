from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import os, asyncio, uvloop

cdef class Client :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
		self.connected = False
		self.reader = None
		self.writer = None

	
	def sendSync(self, bytes message, handle=None) -> None :
		asyncio.run(self.send(message, handle))

	async def send(self, bytes message, handle=None) -> None :
		if not self.connected :
			self.reader, self.writer = await asyncio.open_connection(self.host, self.port)
			self.connected = True
		self.writer.write(message)
		await self.writer.drain()
		received:bytes = await self.reader.read(1024)
		if handle is not None :
			handle(received)