from xtore.BaseType cimport u16, i32
from xtore.algorithm.PrimeNode cimport PrimeNode

cdef class StorageUnit:
	def __init__(self, dict raw):
		self.storageUnitId = raw["storageUnitId"]
		self.layer = raw["layer"]
		self.nodeList = [PrimeNode(node) for node in raw["storageUnit"]]
		self.children = []
		self.index = 0

	def __str__(self):
		nodeDetails = ', '.join(str(node) for node in self.nodeList)
		return f"StorageUnit(ID={self.storageUnitId}, layer={self.layer}, nodeList={nodeDetails}, children={self.children})"
	
	cdef PrimeNode roundRobin(self):
		cdef PrimeNode nodeSelect
		nodeSelect = self.nodeList[self.index]
		self.index = (self.index + 1) % len(self.nodeList)
		return nodeSelect