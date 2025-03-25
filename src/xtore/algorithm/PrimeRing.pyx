from xtore.BaseType cimport i32, i64
from xtore.algorithm.StorageUnit cimport StorageUnit

cdef class PrimeRing:
	def __init__(self, list primeNumbers = [2, 3, 5], i32 replicaNumber = 3):
		self.storageUnits = {}
		self.primeNumbers = primeNumbers
		self.replicaNumber = replicaNumber
		self.hashTable = {}

	cdef loadData(self, dict config):
		self.primeRingConfig = config
		cdef StorageUnit storageUnit
		for i in self.primeRingConfig:
			storageUnit = StorageUnit(self.primeRingConfig[i])
			self.storageUnits[i] = storageUnit
	
	cdef StorageUnit getStorageUnit(self, i64 hashKey):
		cdef i32 previousPosition
		cdef StorageUnit unit, previousUnit
		if hashKey in self.hashTable:
			return self.hashTable[hashKey]
		cdef i32 nodeInLayer = 1
		cdef i32 index = 0
		cdef i32 id = hashKey%self.primeNumbers[index]
		cdef i32 position = id
		cdef i32 previousNode = 0
		cdef i32 nodeSum = 0
		while position < len(self.storageUnits):
			nodeInLayer = nodeInLayer * self.primeNumbers[index]
			nodeSum += nodeInLayer
			id = hashKey%self.primeNumbers[index + 1]
			if (((position - previousNode) * self.primeNumbers[index + 1]) + nodeSum + id) > len(self.storageUnits):
				break
			else:
				previousPosition = position
				position = ((position - previousNode) * self.primeNumbers[index + 1]) + nodeSum + id
				index += 1
			unit = self.storageUnits[str(position)]
			previousUnit = self.storageUnits[str(previousPosition)]
			if (unit.parent != previousUnit.storageUnitId) or (unit.layer != index):
				raise ValueError("Structure not correct: Parent or Layer mismatch")
			previousNode += nodeInLayer
		
		self.hashTable[hashKey] = self.storageUnits[str(position)]
		return self.storageUnits[str(position)]



