from xtore.BaseType cimport i32, i64
from xtore.algorithm.StorageUnit cimport StorageUnit
from xtore.algorithm.PrimeNode cimport PrimeNode

cdef class PrimeRing:
	def __init__(self, list primeNumbers = [2, 3, 5], i32 replicaNumber = 3):
		self.storageUnits = {}
		self.primeNumbers = primeNumbers
		self.replicaNumber = replicaNumber
		self.hashTable = {}
		self.layerFull = {}
		self.currentLayer = 0

	cdef loadData(self, dict config):
		self.primeRingConfig = config
		cdef StorageUnit storageUnit
		cdef i32 layer = 0
		for i in self.primeRingConfig:
			storageUnit = StorageUnit(self.primeRingConfig[i])
			self.storageUnits[i] = storageUnit
		self.checkLayerFulled()

	cdef checkLayerFulled(self):
		cdef StorageUnit unit
		cdef PrimeNode node
		cdef i32 layer
		for unit in self.storageUnits.values():
			for node in unit.nodes.values():
				node.getCapacity()
			layer = unit.layer
			if not unit.isFull():
				self.layerFull[layer] = False
			else:
				self.layerFull[layer] = True
		for layer in range(len(self.primeNumbers)):
			if layer not in self.layerFull:
				break
			if not self.layerFull[layer]:
				self.currentLayer = layer
				break
	
	cdef list[StorageUnit] getStorageUnit(self, i64 hashKey):
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
		cdef list allStorageUnits = []
		cdef i32 startLayer = 0
		while startLayer < self.currentLayer + 1:
			nodeInLayer = nodeInLayer * self.primeNumbers[index]
			nodeSum += nodeInLayer
			allStorageUnits.append(self.storageUnits[str(position)])
			if (index + 1) == len(self.primeNumbers):
				break
			id = hashKey%self.primeNumbers[index + 1]
			if (((position - previousNode) * self.primeNumbers[index + 1]) + nodeSum + id) >= len(self.storageUnits):
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
			startLayer += 1
		self.hashTable[hashKey] = self.storageUnits[str(position)]
		return allStorageUnits

	cdef list[PrimeNode] getAllNodes(self):
		cdef StorageUnit storageUnit
		cdef PrimeNode node
		cdef list nodes = []
		for storageUnit in self.storageUnit.values():
			for node in storageUnit.nodes.values():
				nodes.append(node)
		return nodes



