from xtore.algorithm.ConsistentNode cimport ConsistentNode
from xtore.BaseType cimport i64, i32, u32
import json, random, sys, os

cdef class ConsistentHashing:
	def __init__(self, int replicationFactor=3, int maxNode=1024):
		self.replicationFactor = replicationFactor
		self.maxNode = maxNode
		self.nodes = []
		self.nodeMap = {}

	def __str__(self):
		return f"Nodes: {[node.id for node in self.nodes]}"

	cdef loadData(self, dict config):
		cdef ConsistentNode node
		
		for raw in list(config.values())[0]:
			if "id" not in raw or raw["id"] is None:
				raw["id"] = self.generateNodeID()
			node = ConsistentNode(raw)
			self.nodes.append(node)
			self.nodeMap[node.id] = node
		self.nodes.sort(key=lambda node: node.id)

	cdef i64 generateNodeID(self):
		cdef i64 nodeID
		while True:
			nodeID = <i64> random.randint(0, self.maxNode-1)
			if nodeID not in self.nodeMap: return nodeID

	cdef list[ConsistentNode] getNodeList(self, i64 hashKey):
		cdef i32 hashed = hashKey % self.maxNode
		cdef ConsistentNode node
		cdef i32 low = 0
		cdef i32 high = len(self.nodes) - 1
		cdef i32 i = 0

		while low <= high:
			i = (high+low) // 2
			node = self.nodes[i] 
			if hashed == node.id:
				break
			elif hashed > node.id:
				low = low+1
			elif hashed < node.id:
				high = high-1

		nodes = self.nodes[i:i+self.replicationFactor]
		if len(nodes) < self.replicationFactor: nodes.extend(self.nodes[:self.replicationFactor-len(nodes)])
		print(f"Original hashKey: {hashKey}")
		print(f"Hashed value after mod {self.maxNode}: {hashed}")
		print(f"Selected nodes: {[n.id for n in nodes]}")
		return nodes