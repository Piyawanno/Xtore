from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import sys, os, asyncio#, uvloop

cdef class ServerService :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
	
	def run(self, handle) -> None :
		# if sys.version_info >= (3, 11) :
		# 	with asyncio.Runner(loop_factory=uvloop.new_event_loop) as runner:
		# 		runner.run(self.serve(handle))
		# uvloop.install()
		asyncio.run(self.serve(handle))

	async def serve(self, handle) -> None :
		server:object = await asyncio.start_server(handle, self.host, self.port)
		async with server :
			print(f"Start Socket Server @ {self.host}:{self.port}")
			await server.serve_forever()