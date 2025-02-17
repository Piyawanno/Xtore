from xtore.BaseType cimport u16, i32, i64
from libc.stdlib cimport malloc, free
import os, sys, json
from xtore.service.Node cimport Node

cdef class PrimeRing:
	def __init__(self):
		self.nodes = []
		self.count = 0
		self.primeNumbers = [2, 3, 5]
		self.replicaNumber = 3

	cdef getConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "XtoreNetwork.json")
		cdef object fd
		with open(configPath, "rt") as fd :
			self.config = json.loads(fd.read())
			self.clusterConfig = self.config["cluster"] 
			fd.close()

	cdef initialize(self):
		self.getConfig()
		cdef i32 nodeCount = len(self.clusterConfig["nodes"])
		self.count = nodeCount
		cdef i32 nodeIndex, index
		nodeIndex = 0
		for i in range(0, nodeCount, self.replicaNumber):
			node = self.clusterConfig["nodes"][i]
			masterData = {
				"id": node["id"],
				"host": node["host"],
				"port": node["port"],
				"isMaster": 1,
				"layer": -1,
				"children": [],
				"replicas": [],
			}
			for j in range(i+1, self.replicaNumber):
				replica = self.clusterConfig["nodes"][j]
				masterData["replicas"].append({
					"id": replica["id"],
					"host": replica["host"],
					"port": replica["port"],
					"isMaster": 0,
					"layer": -1,
					"children": [],
					"replicas": [],
				})
			self.nodes.append(masterData)
			nodeIndex = nodeIndex + 1
		self.initPrimeRing()
		self.setConfig()
		
	cdef initPrimeRing(self):
		cdef i32 layer, position, primeIndex, nodeIndex, childIndex, childrenPerNode, num, nodesInLayer
		layer = 0
		position = 0
		primeIndex = 0
		nodeIndex = 0
		while position < self.count and primeIndex < len(self.primeNumbers):
			nodesInLayer = 1	
			num = 0
			while num <= primeIndex:
				nodesInLayer = nodesInLayer * self.primeNumbers[num]
				print(nodesInLayer)
				num = num + 1
			for i in range(nodesInLayer):
				if position < (self.count/self.replicaNumber):
					self.nodes[position]["layer"] = layer
					position = position + 1
			if primeIndex + 1 < len(self.primeNumbers):
				childrenPerNode = self.primeNumbers[primeIndex + 1]
				childIndex = position
				for i in range(nodesInLayer):
					if nodeIndex >= self.count:
						break
					for j in range(childrenPerNode):
						if childIndex < (self.count/self.replicaNumber):
							self.nodes[childIndex]["layer"] = layer + 1
							self.nodes[nodeIndex]["children"].append(self.nodes[childIndex])
							childIndex += 1
					nodeIndex += 1
			layer += 1
			primeIndex += 1

	cdef setConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "PrimeRing.json")
		try:
			with open(configPath, "w") as jsonFile:
				json.dump({"PrimeRing": self.nodes}, jsonFile, indent=4)
			print(f"✅ Successfully wrote file: {configPath}")
		except Exception as e:
			print(f"❌ Error writing file: {e}")
		



