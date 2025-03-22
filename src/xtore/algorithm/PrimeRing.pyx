from xtore.BaseType cimport u8, u16, i32, i64
from libc.stdlib cimport malloc, free
import os, sys, json
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.algorithm.StorageUnit cimport StorageUnit
import itertools

cdef class PrimeRing:
	def __init__(self, list primeNumbers = [2, 3, 5], i32 replicaNumber = 3):
		self.storageUnits = []
		self.primeNumbers = primeNumbers
		self.replicaNumber = replicaNumber
		self.hashTable = {}
		print(f"PrimeRing: {self.primeNumbers}")
		print(f"ReplicaNumber: {self.replicaNumber}")

	cdef loadData(self, list config):
		self.primeRingConfig = config
		cdef PrimeNode primeNode
		cdef StorageUnit storageUnit
		for storage in self.primeRingConfig:
			storageUnit = StorageUnit(storage)
			self.storageUnits.append(storageUnit)
			print(storageUnit)
		#self.initPrimeRing()
		
	cdef initPrimeRing(self):
		cdef list ring = []
		cdef i32 layer, primeIndex, nodeIndex, childrenNumber, nodesInLayer, parent, previousLayer, childIndex
		cdef i32 count
		cdef StorageUnit member
		childIndex = 0
		layer = 0
		primeIndex = 0
		nodeIndex = 0
		count = 0
		parent = 0
		previousLayer = 0
		for member in self.storageUnits:
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
				if childIndex >= len(self.storageUnits):
					break 
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
			print(member)
		self.storageUnits = ring
		self.layerNumber = layer+1
	
	cdef StorageUnit getStorageUnit(self, i64 hashKey):
		cdef i32 id, index, position, nodeInLayer, previousPosition
		cdef list children
		cdef StorageUnit unit, previousUnit
		if hashKey in self.hashTable:
			return self.hashTable[hashKey]
		position = 0
		nodeInLayer = 1
		print(hashKey)
		index = 0
		id = hashKey%self.primeNumbers[index]
		position = id
		while position < len(self.storageUnits):
			nodeInLayer = nodeInLayer * self.primeNumbers[index]
			id = hashKey%self.primeNumbers[index + 1]
			if ((position * self.primeNumbers[index + 1]) + nodeInLayer + id) > len(self.storageUnits):
				break
			else:
				previousPosition = position
				position = (position * self.primeNumbers[index + 1]) + nodeInLayer + id
				index += 1
			unit = self.storageUnits[position]
			previousUnit = self.storageUnits[previousPosition]
			if (unit.parent != previousUnit.storageUnitId) or (unit.layer != index):
				raise ValueError("Structure not correct: Parent or Layer mismatch")
		
		self.hashTable[hashKey] = self.storageUnits[position]
		return self.storageUnits[position]



