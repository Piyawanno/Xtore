from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import os, asyncio

cdef class ServerHandler :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
	
	def run(self) -> None :
		asyncio.run(self.serve())

	async def serve(self) -> None :
		server:object = await asyncio.start_server(self.handle, self.host, self.port)
		async with server :
			print(f"Start Socket Server @ {self.host}:{self.port}")
			await server.serve_forever()

	async def handle(self, reader:object, writer:object) -> None :
		message:bytes = await reader.read(1024)
		print(message)
		writer.write(message)
		await writer.drain()
		writer.close()
		await writer.wait_closed()