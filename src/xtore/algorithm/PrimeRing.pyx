from xtore.BaseType cimport i32, i64
from xtore.algorithm.StorageUnit cimport StorageUnit
from xtore.algorithm.PrimeNode cimport PrimeNode

cdef class PrimeRing:
	def __init__(self, list primeNumbers = [2, 3, 5], i32 replicaNumber = 3):
		self.storageUnits = {}
		self.primeNumbers = primeNumbers
		self.replicaNumber = replicaNumber

	cdef loadData(self, dict config):
		self.primeRingConfig = config
		cdef StorageUnit storageUnit
		cdef i32 layer = 0
		for i in self.primeRingConfig:
			storageUnit = StorageUnit(self.primeRingConfig[i])
			self.storageUnits[i] = storageUnit
	
	cdef list[StorageUnit] getStorageUnit(self, i64 hashKey):
		cdef i32 previousPosition
		cdef StorageUnit unit, previousUnit
		cdef PrimeNode node
		cdef list allStorageUnits = []
		cdef i32 nodeInLayer = 1
		cdef i32 index = 0
		cdef i32 id = hashKey%self.primeNumbers[index]
		cdef i32 position = id
		cdef i32 previousNode = 0
		cdef i32 nodeSum = 0
		while position < len(self.storageUnits):
			nodeInLayer = nodeInLayer * self.primeNumbers[index]
			nodeSum += nodeInLayer
			allStorageUnits.append(self.storageUnits[str(position)])
			if (index + 1) == len(self.primeNumbers):
				break
			id = hashKey%self.primeNumbers[index + 1]
			unit = self.storageUnits[str(position)]
			for node in unit.nodes.values():
				node.getCapacity()
			unit.isFull = unit.checkFull()
			if unit.isFull:
				if (((position - previousNode) * self.primeNumbers[index + 1]) + nodeSum + id) >= len(self.storageUnits):
					raise ValueError("node fulled please expand new layer")
				else:
					previousPosition = position
					position = ((position - previousNode) * self.primeNumbers[index + 1]) + nodeSum + id
					index += 1
			else:
				break
			unit = self.storageUnits[str(position)]
			previousUnit = self.storageUnits[str(previousPosition)]
			if (unit.parent != previousUnit.storageUnitId) or (unit.layer != index):
				raise ValueError("Structure not correct: Parent or Layer mismatch")
			previousNode += nodeInLayer
		return allStorageUnits

	cdef list[PrimeNode] getAllNodes(self):
		cdef StorageUnit storageUnit
		cdef PrimeNode node
		cdef list nodes = []
		for storageUnit in self.storageUnit.values():
			for node in storageUnit.nodes.values():
				nodes.append(node)
		return nodes



