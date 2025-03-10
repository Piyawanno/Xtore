from xtore.BaseType cimport i32, i64
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer, setBuffer
# from xtore.instance.RecordNode cimport RecordNode
from xtore.protocol.RecordNodeProtocol cimport RecordNodeProtocol, DatabaseOperation, InstanceType
from xtore.service.DatabaseClient cimport DatabaseClient
from xtore.test.People cimport People

from libc.stdlib cimport malloc
from cpython cimport PyBytes_FromStringAndSize

import asyncio, uuid

cdef i32 BUFFER_SIZE = 1 << 16

cdef object METHOD = {
	DatabaseOperation.SET: "SET",
	DatabaseOperation.GET: "GET",
	DatabaseOperation.GETALL: "GETALL"
}

cdef class PrimeRingClient (DatabaseClient) :
	def __init__(self, list[dict] nodeList, dict config) :
		self.nodeList = nodeList
		self.primeRing = PrimeRing(primeNumbers = config["primeNumbers"], replicaNumber=config["replicaNumber"])
		self.primeRing.loadData(self.nodeList)
		self.storageUnit = []
		DatabaseClient.__init__(self, nodeList, config)
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self) :
		releaseBuffer(&self.stream)

	def send(self, method, instantType, data) :
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
					record.ID = uuid.uuid4().bytes[:8]
					record.income = <i64> int(row[0])
					record.name = row[1]
					record.surname = row[2]
				print(f"Sending {record.ID}")
				asyncio.run(
					self.request(record.ID, self.encodeData(method, instantType, [record]))
				)
		# elif method == DatabaseOperation.GET :
		# 	for row in data:
		# 		asyncio.run(self.get(record.ID, record.hash()))

	async def request(self, key, message: bytes) :
		cdef People record = People()
		cdef PrimeNode primeRingNode
		cdef list tasks = []
		if not self.connected :
			record.ID = key
			self.storageUnit = self.primeRing.getStorageUnit(record.hash())
			# i=0
			# for replica in self.storageUnit:
			# 	primeRingNode = replica
			# 	task = asyncio.create_task(self.tcpClient(i, message, primeRingNode.host, primeRingNode.port))
			# 	tasks.append(task)
			# 	i+=1
			for replica in self.storageUnit:
				primeRingNode = replica
				if primeRingNode.isMaster == 1:
					task = asyncio.create_task(self.tcpClient(key, message, primeRingNode.host, primeRingNode.port))
					tasks.append(task)
					break
			self.connected = True
			await asyncio.gather(*tasks)
			self.connected = False

	async def tcpClient(self, i: int, message: bytes, host: str, port: int) :
		print(f"Connecting to {i} {host}:{port}")
		reader, writer = await asyncio.open_connection(host, port)
		writer.write(message)
		await writer.drain()
		self.received = await reader.read(1 << 16)
		writer.close()
		await writer.wait_closed()
		print(f"Connection {i} Closed")

	cdef encodeData(self, DatabaseOperation method, InstanceType instanceType, list data) :
		cdef RecordNodeProtocol protocol = RecordNodeProtocol()
		print(f"method: {METHOD[method]}")
		protocol.writeHeader(
			operation=method,
			instantType=instanceType, 
			tableName="People", 
			version=1
		)
		self.stream.position = 0
		protocol.encode(&self.stream, data)
		return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)
