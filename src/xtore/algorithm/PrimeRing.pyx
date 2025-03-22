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



