from xtore.BaseType cimport u16, i32
from xtore.algorithm.PrimeNode cimport PrimeNode
import random

cdef class StorageUnit:
	def __init__(self, dict raw):
		self.storageUnitId = raw["storageUnitId"]
		self.layer = raw["layer"]
		self.nodeList = [PrimeNode(node) for node in raw["storageUnit"]]
		self.parent = raw["parent"]
		self.index = 0
		self.weight = 3
		self.replicaCounter = 0
		self.count = 0
		self.modeFunctionMap = {
			Mode.RoundRobin: self.roundRobin,
			Mode.RoundRobinNoMaster: self.roundRobinNoMaster,
			Mode.WeightRoundRobin: self.weightRoundRobin,
			Mode.AdHoc: self.adHoc,
			Mode.AdHocNoMaster: self.adHocNoMaster,
			Mode.WeightAdHoc: self.weightAdHoc
		}

	def __str__(self):
		nodeDetails = ', '.join(str(node) for node in self.nodeList)
		return f"StorageUnit(ID={self.storageUnitId}, layer={self.layer}, nodeList={nodeDetails}, parent={self.parent})"
	
	cdef PrimeNode getNextNode(self, Mode mode):
		cdef PrimeNode nodeSelect
		nodeSelect = self.modeFunctionMap[mode]()
		return nodeSelect

	
	cdef PrimeNode roundRobin(self):
		cdef PrimeNode nodeSelect
		nodeSelect = self.nodeList[self.index]
		print(self.index)
		self.index = (self.index + 1) % len(self.nodeList)
		return nodeSelect

	cdef PrimeNode roundRobinNoMaster(self):
		if self.index == 0:
			self.index = 1  
		nodeSelect = self.nodeList[self.index]
		print(self.index)
		self.index = (self.index + 1) % len(self.nodeList)
		return nodeSelect

	cdef PrimeNode weightRoundRobin(self):
		nodeSelect = self.nodeList[self.index]
		print(self.index)
		if self.index == 0:
			self.index = 1
			self.replicaCounter = 0
		else:
			self.replicaCounter += 1
			if self.replicaCounter >= len(self.nodeList) - 1:
				self.count += 1
				if self.count == self.weight:
					self.index = 0
					self.replicaCounter = 0
					self.count = 0
				else:
					self.index = 1
					self.replicaCounter = 0
			else:
				self.index = (self.index + 1) % len(self.nodeList)
				if self.index == 0:
					self.index = 1
		return nodeSelect


	cdef PrimeNode adHoc(self):
		nodeSelect = self.nodeList[self.index]
		print(self.index)
		self.index = random.randrange(0,len(self.nodeList))

	cdef PrimeNode adHocNoMaster(self):
		if self.index == 0:
			self.index = 1 
		nodeSelect = self.nodeList[self.index]
		print(self.index)
		self.index = random.randrange(0,len(self.nodeList))

	cdef PrimeNode weightAdHoc(self):
		raise NotImplementedError