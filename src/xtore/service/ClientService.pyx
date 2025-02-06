from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import os, asyncio, uvloop

cdef class ClientService :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
		self.loop = None
	
	def send(self, protocol:asyncio.Protocol, bytes message) -> None :
		self.loop = uvloop.new_event_loop()
		colo = self.loop.create_connection(lambda: protocol(message), self.host, self.port)
		transport, _ = self.loop.run_until_complete(colo)
		try :
			transport.write(message)
		finally :
			transport.close()