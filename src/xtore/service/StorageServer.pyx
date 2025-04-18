from xtore.protocol.StorageTransferProtocol cimport StorageTransferProtocol
from xtore.service.StorageHandler cimport StorageHandler

import asyncio, uvloop

cdef class StorageServer :
	def __init__(self, dict config) :
		self.config = config
		self.host = self.config["host"]
		self.port = self.config["port"]
		self.storageHandler = StorageHandler({})
	
	def run(self) :
		uvloop.install()
		print(f"Start Storage Service ✨")
		self.storage = self.storageHandler.openBSTStorage("People.BST.bin")
		asyncio.run(self.serve())

	def createProtocol(self) :
		return StorageTransferProtocol(self.storageHandler, self.storage)

	async def serve(self) -> None :
		loop = asyncio.get_event_loop()
		server: object = await loop.create_server(self.createProtocol, self.host, self.port)
		print(f"Start Socket Server @ {self.host}:{self.port}")
		async with server:
			await server.serve_forever()