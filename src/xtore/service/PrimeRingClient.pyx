from xtore.BaseType cimport i32, i64
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.algorithm.StorageUnit cimport StorageUnit
from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.common.Buffer cimport initBuffer, releaseBuffer, setBuffer
# from xtore.instance.RecordNode cimport RecordNode
from xtore.protocol.RecordNodeProtocol cimport RecordNodeProtocol, DatabaseOperation, InstanceType
from xtore.service.DatabaseClient cimport DatabaseClient
from xtore.test.People cimport People

import asyncio, uuid

cdef i32 BUFFER_SIZE = 1 << 16

cdef object METHOD = {
	DatabaseOperation.SET: "SET",
	DatabaseOperation.GET: "GET",
	DatabaseOperation.GETALL: "GETALL"
}

cdef class PrimeRingClient (DatabaseClient) :
	def __init__(self, dict nodeList, dict config) :
		DatabaseClient.__init__(self)
		self.nodeList = nodeList
		self.primeRing = PrimeRing(primeNumbers = config["primeNumbers"], replicaNumber=config["replicaNumber"])
		self.primeRing.loadData(self.nodeList)
		
		self.storageUnit = {}

	cdef send(self, DatabaseOperation method, InstanceType instantType, str tableName, list data) :
		cdef People record
		if method == DatabaseOperation.SET :
			for row in data[1:]:
				record = People()
				if data[0][0] == "ID" :
					record.ID = <i64> int(row[0])
					record.income = <i64> int(row[1])
					record.name = row[2]
					record.surname = row[3]
				else :
					record.ID = <i64> int.from_bytes(uuid.uuid4().bytes[:2])
					record.income = <i64> int(row[0])
					record.name = row[1]
					record.surname = row[2]
				asyncio.run(self.request(method, record.ID, self.encodeData(method, instantType, tableName, [record])))
		elif method == DatabaseOperation.GET :
			for row in data[1:]:
				record = People()
				record.ID = <i64> int(row[0])
				record.income = 0
				record.name = ""
				record.surname = ""
				asyncio.run(self.request(method, record.ID, self.encodeData(method, instantType, tableName, [record])))
		elif method == DatabaseOperation.GETALL :
			asyncio.run(self.request(method, None, self.encodeData(method, instantType, tableName, [])))

	async def request(self, method: int, key: int | None, message: bytes) :
		cdef People record = People()
		cdef PrimeNode primeRingNode
		cdef StorageUnit storageUnit
		cdef list tasks = []
		cdef str methodCode = METHOD[method][0::3]
		if not self.connected :
			if method == DatabaseOperation.GETALL :
				for node in self.primeRing.nodes:
					primeRingNode = node
					if primeRingNode.isMaster == 1:
						task = asyncio.create_task(self.tcpClient(f"{methodCode}{int.from_bytes(uuid.uuid4().bytes[:2]):05d}", message, primeRingNode.host, primeRingNode.port))
						tasks.append(task)
				self.connected = True
				await asyncio.gather(*tasks)
				self.connected = False
			else :
				record.ID = key
				storageUnit = self.primeRing.getStorageUnit(record.hash())
				self.storageUnit = storageUnit.nodes
				for replica in self.storageUnit.values():
					primeRingNode = replica
					if primeRingNode.isMaster == 1:
						task = asyncio.create_task(self.tcpClient(f"{methodCode}{key}", message, primeRingNode.host, primeRingNode.port))
						self.connected = True
						await task
						self.connected = False
						break

	async def tcpClient(self, processID: str, message: bytes, host: str, port: int) :
		cdef str prefix = f"[{processID}]({host}:{port})"
		reader, writer = await asyncio.open_connection(host, port)
		writer.write(message)
		await writer.drain()
		self.received = await reader.read(1 << 16)
		for record in self.decodeData(self.received):
			print(f"{prefix} >> FOUND {record}")
		writer.close()
		await writer.wait_closed()
