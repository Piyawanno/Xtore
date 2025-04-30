from xtore.BaseType cimport i32, i64
from xtore.algorithm.PrimeNode cimport PrimeNode
import random

cdef i64 MAX_CAPACITY = 5000

cdef class StorageUnit:
	def __init__(self, dict raw):
		self.storageUnitId = raw["storageUnitId"]
		self.layer = raw["layer"]
		self.nodes = {i: PrimeNode(raw["storageUnit"][i]) for i in raw["storageUnit"]}
		self.parent = raw["parent"]
		self.index = 0
		self.weight = 3
		self.replicaCounter = 0
		self.count = 0
		self.loadBalanceMode = {
			LoadBalanceMode.ROUND_ROBIN: self.getRoundRobin,
			LoadBalanceMode.NO_MASTER_ROUND_ROBIN: self.getNoMasterRoundRobin,
			LoadBalanceMode.WEIGHT_ROUND_ROBIN: self.getWeightRoundRobin,
			LoadBalanceMode.ADHOC: self.getAdHoc,
			LoadBalanceMode.NO_MASTER_ADHOC: self.getNoMasterAdHoc,
			LoadBalanceMode.WEIGHT_ADHOC: self.getWeightAdHoc
		}
		self.isFull = self.checkFull()

	def __str__(self):
		nodeDetails = ', '.join(str(self.nodes[i]) for i in self.nodes)
		return f"StorageUnit(ID={self.storageUnitId}, layer={self.layer}, nodes={{{nodeDetails}}}, parent={self.parent})"

	cdef bint checkFull(self):
		cdef PrimeNode node
		for node in self.nodes.values():
			if node.capacity < MAX_CAPACITY:
				return False
		return True

	cdef PrimeNode getNextNode(self, LoadBalanceMode mode):
		cdef PrimeNode nodeSelect = self.loadBalanceMode[mode]()
		return nodeSelect
	
	cdef PrimeNode getRoundRobin(self):
		cdef PrimeNode nodeSelect = self.nodes[str(self.index)]
		self.index = (self.index + 1) % len(self.nodes)
		return nodeSelect

	cdef PrimeNode getNoMasterRoundRobin(self):
		if self.index == 0:
			self.index = 1  
		cdef PrimeNode nodeSelect = self.nodes[str(self.index)]
		self.index = (self.index + 1) % len(self.nodes)
		return nodeSelect

	cdef PrimeNode getWeightRoundRobin(self):
		cdef PrimeNode nodeSelect = self.nodes[str(self.index)]
		if self.index == 0:
			self.index = 1
			self.replicaCounter = 0
		else:
			self.replicaCounter += 1
			if self.replicaCounter >= len(self.nodes) - 1:
				self.count += 1
				if self.count == self.weight:
					self.index = 0
					self.replicaCounter = 0
					self.count = 0
				else:
					self.index = 1
					self.replicaCounter = 0
			else:
				self.index = (self.index + 1) % len(self.nodes)
				if self.index == 0:
					self.index = 1
		return nodeSelect

	cdef PrimeNode getAdHoc(self):
		cdef PrimeNode nodeSelect = self.nodes[str(self.index)]
		self.index = random.randrange(0,len(self.nodes))

	cdef PrimeNode getNoMasterAdHoc(self):
		if self.index == 0:
			self.index = 1 
		cdef PrimeNode nodeSelect = self.nodes[str(self.index)]
		self.index = random.randrange(0,len(self.nodes))

	cdef PrimeNode getWeightAdHoc(self):
		cdef PrimeNode nodeSelect = self.nodes[str(self.index)]
		cdef dict weightMapper = {}
		for key in self.nodes:
			if key == "0":
				weightMapper[key] = 1
			else:
				weightMapper[key] = self.weight
		self.index = int(random.choices(list(weightMapper.keys()), weights=list(weightMapper.values()), k=1)[0])
		return nodeSelect