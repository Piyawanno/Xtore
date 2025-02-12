from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16
from xtore.protocol.EchoProtocol cimport EchoProtocol

import sys, os, asyncio, uvloop

cdef class UVServerService :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
	
	def run(self, protocol) -> None :
		uvloop.install()
		asyncio.run(self.serve(protocol))

	async def serve(self, protocol) -> None :
		loop = asyncio.get_event_loop()
		server: object = await loop.create_server(lambda: protocol, self.host, self.port)
		print(f"Start Socket Server @ {self.host}:{self.port}")
		async with server:
			await server.serve_forever()
