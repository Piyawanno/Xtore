from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import os, asyncio

cdef class ClientService :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
	
	def send(self, bytes message, handle=None) -> None :
		asyncio.run(self.connect(message, handle))

	async def connect(self, bytes message, handle) -> None :
		reader, writer = await asyncio.open_connection(self.host, self.port)
		writer.write(message)
		await writer.drain()
		received:bytes = await reader.read(1024)
		writer.close()
		await writer.wait_closed()
		if handle is not None :
			handle(received)