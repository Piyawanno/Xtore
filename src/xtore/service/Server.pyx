from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16

import sys, os, asyncio, uvloop

cdef class Server :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
		self.loop = None
	
	def run(self, protocol:asyncio.Protocol) -> None :
		self.loop = uvloop.new_event_loop()
		asyncio.set_event_loop(self.loop)
		# def createProtocol() :
		# 	return ReplicaProtocol()
		# colo = self.loop.create_server(createProtocol, self.host, self.port)
		colo = self.loop.create_server(protocol, self.host, self.port)
		self.loop.run_until_complete(colo)
		print(f"Start Socket Server @ {self.host}:{self.port}")
		try :
			self.loop.run_forever()
		finally :
			self.loop.close()