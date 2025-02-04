from xtore.BaseType cimport i32, u64
import json

cdef class PrimeRingP:
	def __init__(self, list primeNumbers):
		self.numLayers = 1
		self.primeNumbers = primeNumbers
		self.layers = [{}]
		self.nodes = []
		self.maxNodeLayer = primeNumbers[0]

	cdef u64 getNode(self, u64 key):
		cdef i32 layer, index
		for layer in range(self.numLayers):
			index = self.getIndex(key, layer)
			if index in self.layers[layer]:
				return self.layers[layer][index]
		return -1

	cdef u64 getIndex(self, u64 key, i32 layer):
		return key % self.primeNumbers[layer]

	cdef insertNode(self, dict info):
		layer = info['layer']
		nodeID = info['id']
		if len(self.layers[layer]) >= self.primeNumbers[layer]:
			self.insertLayer()
			layer += 1

		self.nodes.append(info)
		self.layers[layer][nodeID] = info

	cdef insertLayer(self):
		self.layers.append({})
		self.numLayers += 1
