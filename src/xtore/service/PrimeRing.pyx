from xtore.BaseType cimport u8, u16, i32, i64
from libc.stdlib cimport malloc, free
import os, sys, json
from xtore.service.PrimeNode cimport PrimeNode

cdef class PrimeRing:
	def __init__(self):
		self.nodes = []
		self.primeNumbers = [2, 3, 5]
		self.replicaNumber = 3
		self.nodeNumber = 0

	cdef loadData(self, dict config):
		self.primeRingConfig = config["primeRing"]
		cdef PrimeNode primeNode
		for node in self.primeRingConfig:
			primeNode = PrimeNode(node)
			self.nodes.append(primeNode)
			self.nodeNumber += 1
		self.initPrimeRing()
		
	cdef initPrimeRing(self):
		cdef list ring = []
		cdef i32 layer, primeIndex, nodeIndex, childrenNumber, nodesInLayer, parent, previousLayer, childIndex
		cdef i32 count
		cdef PrimeNode member, childNode
		childIndex = 0
		layer = 0
		primeIndex = 0
		nodeIndex = 0
		count = 0
		parent = 0
		previousLayer = 0
		for i, member in enumerate(self.nodes):
			if member.isMaster == 0:
				ring.append(member)
				continue
			nodesInLayer = 1
			for index, prime in enumerate(self.primeNumbers):
				nodesInLayer = nodesInLayer * prime
				if index == primeIndex:
					break
			if nodeIndex + 1 == len(self.primeNumbers):
				break
			childrenNumber = self.primeNumbers[nodeIndex + 1]
			if parent == previousLayer:
				childIndex = (count + nodesInLayer) * self.replicaNumber
				parent = 0
			for j in range(childrenNumber):
				if childIndex >= len(self.nodes):
					break 
				childNode = self.nodes[childIndex]
				member.children.append(childIndex)
				childIndex += self.replicaNumber
			parent += 1
			if parent == nodesInLayer:
				nodeIndex += 1
				count += nodesInLayer
				primeIndex += 1
				layer += 1
				previousLayer = nodesInLayer
			ring.append(member)
			print(member)
		self.nodes = ring
		self.layerNumber = layer+1
		
	cdef list getNode(self, i32 hashKey):
		cdef PrimeNode node, nodem
		cdef i32 id, index, position
		cdef list children, storageUnit = []
		position = 0
		print(hashKey)
		index = 0
		id = hashKey%self.primeNumbers[index]
		position = id * self.replicaNumber
		while position < self.nodeNumber:
			node = self.nodes[position]
			if node.children:
				id = hashKey%self.primeNumbers[index + 1]
				position = node.children[id]
			else:
				break
		for i in range(self.replicaNumber):
			storageUnit.append(self.nodes[position])
			position += 1
		return storageUnit




