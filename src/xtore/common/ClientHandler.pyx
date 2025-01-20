from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import os, asyncio

cdef class ClientHandler :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
	
	def send(self) -> None :
		asyncio.run(self.connect())

	async def connect(self) -> None :
		reader, writer = await asyncio.open_connection(self.host, self.port)
		writer.write(b"\n\n\n")
		await writer.drain()
		message:bytes = await reader.read(1024)
		print(message)
		writer.close()
		await writer.wait_closed()