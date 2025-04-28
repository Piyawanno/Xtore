from xtore.BaseType cimport i32, i64
from xtore.algorithm.StorageUnit cimport StorageUnit

cdef class PrimeRingMinus:
	def __init__(self, list primeNumbers = [2, 3, 7], i32 replicaNumber = 3):
		self.storageUnits = {}
		self.primeNumbers = primeNumbers
		self.replicaNumber = replicaNumber
		self.hashTable = {}

	cdef loadData(self, dict config):
		self.primeRingConfigMinus = config
		cdef StorageUnit storageUnit
		for i in self.primeRingConfigMinus:
			storageUnit = StorageUnit(self.primeRingConfigMinus[i])
			self.storageUnits[i] = storageUnit
	
	cdef StorageUnit getStorageUnit(self, i64 hashKey):
		cdef i32 previousPosition
		cdef StorageUnit unit, previousUnit
		cdef i32 nodeInLayer = 1
		cdef i32 index = 0
		cdef i32 id = hashKey%self.primeNumbers[index]
		cdef i32 position = id
		cdef i32 previousNode = 0
		cdef i32 nodeSum = 0
		
		if hashKey in self.hashTable:
			unit = self.hashTable[hashKey]
			if unit.layer == len(self.primeNumbers) - 1:
				return unit
			else:
				index = 0
				while index <= unit.layer:
					nodeInLayer = nodeInLayer * self.primeNumbers[index]
					nodeSum += nodeInLayer
					previousNode += nodeInLayer
					index += 1
				id = hashKey % self.primeNumbers[index]
				position = nodeSum + id

				while position < len(self.storageUnits):
					nodeInLayer = nodeInLayer * self.primeNumbers[index]
					nodeSum += nodeInLayer
					if (index + 1) == len(self.primeNumbers):
						break
					id = hashKey % self.primeNumbers[index + 1]
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
		else:
			index = 0
			while index < len(self.primeNumbers):
				nodeInLayer = nodeInLayer * self.primeNumbers[index]
				nodeSum += nodeInLayer
				index += 1
			id = hashKey % nodeInLayer
			position = nodeSum - nodeInLayer + id - 1

		self.hashTable[hashKey] = self.storageUnits[str(position)]
		return self.storageUnits[str(position)]