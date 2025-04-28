from xtore.algorithm.ConsistentNode cimport ConsistentNode
from xtore.BaseType cimport i64, i32
import json, random, sys, os

cdef class ConsistentHashing:
	def __init__(self, i32 replicationFactor=3, i32 maxNode=1024):
		self.replicationFactor = replicationFactor
		self.maxNode = maxNode
		self.nodes = []
		self.nodeMapper = {}
		self.hashTable = {}

	def __str__(self):
		return f"Nodes: {[node.id for node in self.nodes]}"

	cdef loadData(self, dict config):
		cdef ConsistentNode node
		
		for raw in config.values():
			if "id" not in raw or raw["id"] is None:
				raw["id"] = self.generateNodeID()
			node = ConsistentNode(raw)
			self.nodes.append(node)
			self.nodeMapper[node.id] = node
		self.nodes.sort(key=lambda node: node.id)

	cdef i64 generateNodeID(self):
		cdef i64 nodeID
		while True:
			nodeID = <i64> random.randint(0, self.maxNode-1)
			if nodeID not in self.nodeMapper: return nodeID

	cdef list[ConsistentNode] getNodeList(self, i64 hashKey):
		if hashKey in self.hashTable:
			return self.hashTable[hashKey]
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
				low = i+1
			elif hashed < node.id:
				high = i-1
		
		if hashed > node.id:
			i += 1

		nodes = self.nodes[i:i+self.replicationFactor]
		
		if len(nodes) < self.replicationFactor: nodes.extend(self.nodes[:self.replicationFactor-len(nodes)])
		self.hashTable[hashKey] = nodes

		return nodes