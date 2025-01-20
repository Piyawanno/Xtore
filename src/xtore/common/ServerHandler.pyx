from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import os, asyncio

cdef class ServerHandler :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
	
	def run(self, handle) -> None :
		asyncio.run(self.serve(handle))

	async def serve(self, handle) -> None :
		server:object = await asyncio.start_server(handle, self.host, self.port)
		async with server :
			print(f"Start Socket Server @ {self.host}:{self.port}")
			await server.serve_forever()