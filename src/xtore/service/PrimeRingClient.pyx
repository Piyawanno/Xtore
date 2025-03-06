# from xtore.service.StorageClient cimport StorageClient
from xtore.algorithm.PrimeRing cimport PrimeRing
# from xtore.instance.RecordNode cimport RecordNode
from xtore.test.People cimport People

import asyncio

cdef class PrimeRingClient :
	def __init__(self, dict config) :
		self.config = config
		self.primeRing = PrimeRing()
		self.primeRing.loadData(config)
		self.storageUnit = []
		self.connected = False
		self.reader = None
		self.writer = None
		self.received = None

	def send(self, key, message: bytes) :
		return asyncio.run(self.request(key, message))

	async def request(self, key, message: bytes) :
		cdef People record = People()
		tasks = []
		if not self.connected :
			record.ID = key
			self.storageUnit = self.primeRing.getNode(record.hash())
			i=0
			for replica in self.storageUnit:
				task = asyncio.create_task(self.tcpClient(i, message, replica.host, replica.port))
				tasks.append(task)
				i+=1
			self.connected = True
			await asyncio.gather(*tasks)
			self.connected = False

	async def tcpClient(self, i: int, message: bytes, host: str, port: int) :
		print(f"Connecting to {host}:{port}")
		reader, writer = await asyncio.open_connection(host, port)
		writer.write(message)
		await writer.drain()
		self.received = await reader.read(1 << 16)
		writer.close()
		await writer.wait_closed()
		print("Connection Closed")
 