from xtore.BaseType cimport i32, i64, u64
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.algorithm.StorageUnit cimport StorageUnit
from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.common.Buffer cimport initBuffer, releaseBuffer, setBuffer
from xtore.instance.RecordNode cimport RecordNode
from xtore.protocol.RecordNodeProtocol cimport RecordNodeProtocol, DatabaseOperation, InstanceType
from xtore.service.DatabaseClient cimport DatabaseClient
from xtore.service.PrimeRingErrorHandler cimport PrimeRingErrorHandler
from xtore.test.People cimport People

from collections import Counter
import asyncio, uuid, time

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
		self.handler = PrimeRingErrorHandler()
		
		self.storageUnit = {}

	cdef send(self, DatabaseOperation method, InstanceType instantType, str tableName, list data) :
		cdef People record
		cdef i64 totalHit = 0
		cdef i64 totalAmount = 0
		cdef list successList = []
		cdef bytes message
		cdef dict newNodes = {}
		cdef StorageUnit newStorage
		cdef PrimeNode newPrimeNode
		cdef People failedRecord = People()

		if method == DatabaseOperation.SET :
			start = time.time()
			for row in data[1:]:
				record = People()
				if data[0][0] == "ID" :
					record.ID = <u64> int(row[0])
					record.income = <i64> int(row[1])
					record.name = row[2]
					record.surname = row[3]
				else :
					record.ID = <u64> int.from_bytes(uuid.uuid4().bytes[:2])
					record.income = <i64> int(row[0])
					record.name = row[1]
					record.surname = row[2]
				message = self.encodeData(method, instantType, tableName, [record])
				asyncio.run(self.request(method, record.ID, message))
			print(f">> Elapsed time before resend: {time.time() - start:.2f} seconds")
			asyncio.run(self.handler.resend(self.tcpClient, method, self.primeRing))
			print(f">> Elapsed time after resend: {time.time() - start:.2f} seconds")
		elif method == DatabaseOperation.GET :
			start = time.time()
			for row in data[1:]:
				record = People()
				record.ID = <u64> int(row[0])
				record.income = 0
				record.name = ""
				record.surname = ""
				successReturn = asyncio.run(self.request(method, record.ID, self.encodeData(method, instantType, tableName, [record])))
				successList.append(successReturn)
			print(f">> Elapsed time before resend: {time.time() - start:.2f} seconds")
			asyncio.run(self.handler.resend(self.tcpClient, method, self.primeRing))
			for pair in successList:
				totalHit += pair[0]
				totalAmount += pair[1]
			if totalAmount > 0:
				successRate = (totalHit / totalAmount) * 100
				print(f">> {totalHit}/{totalAmount} records {successRate}% success rate.")
			else:
				print(f">> {totalHit}/{totalAmount} records 0% success rate.")
			print(f">> Elapsed time after resend: {time.time() - start:.2f} seconds")
		elif method == DatabaseOperation.GETALL :
			asyncio.run(self.request(method, None, self.encodeData(method, instantType, tableName, [])))

	async def request(self, method: int, key: int | None, message: bytes) :
		cdef People record = People()
		cdef PrimeNode primeRingNode
		cdef StorageUnit storageUnit
		cdef list tasks = []
		cdef str methodCode = METHOD[method][0::3]
		cdef i64 totalHit = 0
		cdef i64 totalAmount = 0
		cdef list successList = []
		if not self.connected :
			if method == DatabaseOperation.GETALL :
				for node in self.primeRing.nodes:
					primeRingNode = node
					if primeRingNode.isMaster == 1:
						task = asyncio.create_task(self.handler.handleError(f"{methodCode}{int.from_bytes(uuid.uuid4().bytes[:2]):05d}", message, primeRingNode.host, primeRingNode.port, self.tcpClient))
						tasks.append(task)
				self.connected = True
				successList = await asyncio.gather(*tasks)
				self.connected = False
			if method == DatabaseOperation.GET :
				record.ID = key
				storageUnits = self.primeRing.getStorageUnit(record.hash())[::-1]
				for storageUnit in storageUnits:
					self.storageUnit = storageUnit.nodes
					for replica in self.storageUnit.values():
						primeRingNode = replica
						if primeRingNode.isMaster == 1:
							task = asyncio.create_task(self.handler.handleError(f"{methodCode}{key}", message, primeRingNode.host, primeRingNode.port, self.tcpClient))
							tasks.append(task)
							break
				self.connected = True
				successReturn = None
				for task in asyncio.as_completed(tasks):
					result = await task
					if result == (1, 1):
						successReturn = result
						break
				if successReturn is None:
					successReturn = (0, 0)
				successList = [successReturn]
				self.connected = False
			else :
				record.ID = key
				storageUnit = self.primeRing.getStorageUnit(record.hash())[-1]
				self.storageUnit = storageUnit.nodes
				for replica in self.storageUnit.values():
					primeRingNode = replica
					task = asyncio.create_task(self.handler.handleError(f"{methodCode}{key}", message, primeRingNode.host, primeRingNode.port, self.tcpClient))
					tasks.append(task)
				self.connected = True
				successList = await asyncio.gather(*tasks)
				self.connected = False
		for pair in successList:
			totalHit += pair[0]
			totalAmount += pair[1]
		return totalHit, totalAmount

	async def tcpClient(self, processID: str, message: bytes, host: str, port: int) :
		cdef str prefix = f"[{processID}]({host}:{port})"
		reader, writer = await asyncio.open_connection(host, port)
		writer.write(message)
		await writer.drain()
		self.received = await reader.read(1 << 16)
		cdef People people
		cdef i32 success = 0
		cdef i32 amount = 1
		if self.decodeData(self.received) == []:
			print(f"{prefix} >> NOT FOUND")
			writer.close()
			await writer.wait_closed()
			return success, amount
		for record in self.decodeData(self.received):
			if isinstance(record, People):
				people = record
				if people.income == 0 and people.name == "" and people.surname == "":
					print(f"{prefix} >> NOT FOUND")
				else:
					print(f"{prefix} >> {record}")
					success += 1
			else:
				print(f"{prefix} >> FOUND {record}")
				success += 1
		writer.close()
		await writer.wait_closed()

		return success, amount
