from xtore.BaseType cimport u8, u16, i32, i64
from libc.stdlib cimport malloc, free
import os, sys, json
from xtore.service.Node cimport Node
from xtore.instance.RecordNode cimport hashDJB

cdef class PrimeRing:
	def __init__(self):
		self.nodes = []
		self.primeNumbers = [2, 3, 5]
		self.replicaNumber = 3
		self.nodeNumber = 0

	cdef getConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			self.primeRingConfig = self.config["primeRing"]
			fd.close()

	cdef loadData(self):
		self.getConfig()
		cdef Node storageUnit
		for i, layer in enumerate(self.primeRingConfig):
			for storage in layer["childStorageUnit"]:
				storageUnit = Node(storage, i)
				self.nodes.append(storageUnit)
				self.nodeNumber += 1
		self.initPrimeRing()
		self.setConfig()
		
	cdef initPrimeRing(self):
		cdef list ring = []
		cdef i32 layer, primeIndex, nodeIndex, childrenNumber, nodesInLayer, parent, previousLayer
		cdef i32 count
		cdef Node member, childNode
		layer = 0
		primeIndex = 0
		nodeIndex = 0
		count = 0
		parent = 0
		previousLayer = 0
		for i, member in enumerate(self.nodes):
			nodesInLayer = 1
			for index, prime in enumerate(self.primeNumbers):
				nodesInLayer = nodesInLayer * prime
				if index == primeIndex:
					break
			if nodeIndex + 1 == len(self.primeNumbers):
				break
			childrenNumber = self.primeNumbers[nodeIndex + 1]
			if parent == previousLayer:
				childIndex = count + nodesInLayer
				parent = 0
			for j in range(childrenNumber):
				if childIndex >= len(self.nodes):
					break 
				childNode = self.nodes[childIndex]
				member.children.append(childIndex)
				childIndex += 1
			parent += 1
			if parent == nodesInLayer:
				nodeIndex += 1
				count += nodesInLayer
				primeIndex += 1
				layer += 1
				previousLayer = nodesInLayer
			ring.append(member)
		self.nodes = ring

	cdef setConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "PrimeRing.json")
		cdef Node nodeForWrite, child
		cdef list nodeList = []
		for nodeMember in self.nodes:
			nodeForWrite = nodeMember
			nodeData = {
				"id": nodeForWrite.id,
				"host": nodeForWrite.host,
				"port": nodeForWrite.port,
				"layer": nodeForWrite.layer,
				"children": nodeForWrite.children,
				"replicas": nodeForWrite.replicas,
			}
			print(nodeData)
			nodeList.append(nodeData)
		try:
			with open(configPath, "w") as jsonFile:
				json.dump({"PrimeRing": nodeList}, jsonFile, indent=4)
			print(f"Successfully wrote file: {configPath}")
		except Exception as e:
			print(f"Error writing file: {e}")
		
	cdef dict getNodeForSet(self, char * key):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "PrimeRing.json")
		cdef object fd
		cdef dict config
		cdef list nodeConfig
		with open(configPath, "rt") as fd:
			config = json.loads(fd.read())
			nodeConfig = config["PrimeRing"]
			fd.close()
		cdef i32 hashKey, id, index, position
		position = 0
		hashKey = hashDJB(key, 10)
		index = 0
		id = hashKey%self.primeNumbers[index]
		while position < self.nodeNumber:
			if nodeConfig[position]["children"]:
				id = hashKey%self.primeNumbers[index + 1]
				position = nodeConfig[position]["children"][id]
			else:
				break
		return {
			"host": nodeConfig[position]["host"],
			"port": nodeConfig[position]["port"]
		}
	
	cdef dict getNodeForGet(self, i32 index):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "PrimeRing.json")
		cdef object fd
		cdef dict config
		cdef list nodeConfig
		with open(configPath, "rt") as fd:
			config = json.loads(fd.read())
			nodeConfig = config["PrimeRing"]
			fd.close()
		return {
			"host": nodeConfig[index]["host"],
			"port": nodeConfig[index]["port"]
		}



