from xtore.BaseType cimport u16, i32, i64
from libc.stdlib cimport malloc, free
import os, sys, json
from xtore.service.Node cimport Node

cdef class PrimeRing:
	def __init__(self):
		self.nodes = []
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
		cdef Node node, replicaNode
		cdef i32 num, check
		num = 0
		print(self.clusterConfig["nodes"][0])
		for i, raw in enumerate(self.clusterConfig["nodes"]):
			check = i+1
			node = Node(raw)
			node.isMaster = 1
			"""for j in range(i+1, self.replicaNumber):
				replica = self.clusterConfig["nodes"][j]
				masterData["replicas"].append({
					"id": replica["id"],
					"host": replica["host"],
					"port": replica["port"],
					"isMaster": 0,
					"layer": -1,
					"children": [],
					"replicas": [],
				})"""
			if num != 0:
				num -= 1
				continue
			else:
				for iterate in range(self.replicaNumber - 1):
					replicaNode = Node(self.clusterConfig["nodes"][check])
					replicaNode.isMaster = 0
					node.replicas.append(replicaNode)
					num += 1
					check += 1
			print(node.port)
			self.nodes.append(node)
		cdef Node n = self.nodes[0]
		print(n.port)
		self.initPrimeRing()
		cdef Node a = self.nodes[0]
		cdef Node b = a.replicas[0]
		print(b.id)
		self.setConfig()
		
	cdef initPrimeRing(self):
		pass
		cdef list ring = []
		cdef i32 layer, primeIndex, nodeIndex, childrenNumber, nodesInLayer, parent
		cdef i32 count
		cdef Node member, children
		layer = 0
		primeIndex = 0
		nodeIndex = 0
		count = 0
		parent = 0
		childIndex = self.primeNumbers[0]
		for i, member in enumerate(self.nodes):
			print(member.id)
			nodesInLayer = 1
			for index, prime in enumerate(self.primeNumbers):
				nodesInLayer = nodesInLayer * prime
				if index == primeIndex:
					break
			childrenNumber = self.primeNumbers[nodeIndex + 1]
			if parent == nodesInLayer:
				childIndex = count + nodesInLayer
				parent = 0
			member.layer = layer
			for j in range(childrenNumber):
				if childIndex >= len(self.nodes):
					break 
				childNode = Node(self.nodes[childIndex])
				childNode.layer = layer + 1
				member.children.append(childNode)
				childIndex += 1
			parent += 1
			if parent == nodesInLayer:
				nodeIndex += 1
				count += nodesInLayer
				primeIndex += 1
				layer += 1
			ring.append(member)
		self.nodes = ring

	cdef setConfig(self):
		cdef str configPath = os.path.join(sys.prefix, "etc", "xtore", "PrimeRing.json")
		cdef Node nodeForWrite, child, replica
		cdef list nodeList = []
		for nodeMember in self.nodes:
			nodeForWrite = nodeMember
			nodeData = {
				"id": nodeForWrite.id,
				"host": nodeForWrite.host,
				"port": nodeForWrite.port,
				"isMaster": nodeForWrite.isMaster,
				"layer": nodeForWrite.layer,
				"children": [],
				"replicas": [],
			}
			for child in nodeForWrite.children:
				childData = {
					"id": child.id,
					"host": child.host,
					"port": child.port,
					"isMaster": child.isMaster,
					"layer": child.layer,
				}
				nodeData["children"].append(childData)
			for replica in nodeForWrite.replicas:
				replicaData = {
					"id": replica.id,
					"host": replica.host,
					"port": replica.port,
					"isMaster": replica.isMaster,
				}
				nodeData["replicas"].append(replicaData)
			nodeList.append(nodeData)
		try:
			with open(configPath, "w") as jsonFile:
				json.dump({"PrimeRing": nodeList}, jsonFile, indent=4)
			print(f"Successfully wrote file: {configPath}")
		except Exception as e:
			print(f"Error writing file: {e}")
		



