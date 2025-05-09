from xtore.BaseType cimport u64
from xtore.test.People cimport People
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.algorithm.StorageUnit cimport StorageUnit
from xtore.protocol.RecordNodeProtocol cimport DatabaseOperation
import asyncio

cdef object METHOD = {
	DatabaseOperation.SET: "SET",
	DatabaseOperation.GET: "GET",
	DatabaseOperation.GETALL: "GETALL"
}

cdef class ErrorHandler:
	def __init__(self):
		self.failedData = []
		self.semaphore = asyncio.Semaphore(100)

	async def handleError(self, processID: str, message: bytes, host: str, port: int, object tcpFunction):
		async with self.semaphore:
			try:
				result = await tcpFunction(processID, message, host, port)
				return result
			except (asyncio.TimeoutError, ConnectionRefusedError, ConnectionError, OSError) as e:
				print(f"[{processID}]({host}:{port}) >> ERROR {str(e)}")
				self.failedData.append((processID, message, host, port))
				return (0, 0)

	async def resend(self, object tcpFunction, DatabaseOperation method):
		cdef list tasks = []
		cdef People record = People()
		cdef StorageUnit storageUnit
		cdef PrimeNode primeRingNode
		cdef dict nodes = {}
		while self.failedData:
			print(f">> Retrying {len(self.failedData)} failed request(s)...")
			current = self.failedData
			self.failedData = []
			for processID, message, host, port in current:
				if method == DatabaseOperation.SET :
					record.ID = <u64> int(processID)
					storageUnit = self.primeRing.getStorageUnit(record.hash())[-1]
					nodes = storageUnit.nodes
					for replica in nodes.values():
						primeRingNode = replica
						task = asyncio.create_task(self.handler.handleError(processID, message, primeRingNode.host, primeRingNode.port, self.tcpClient))
						tasks.append(task)
				else:
					task = asyncio.create_task(self.handleError(processID, message, host, port, tcpFunction))
					tasks.append(task)
			await asyncio.gather(*tasks)
