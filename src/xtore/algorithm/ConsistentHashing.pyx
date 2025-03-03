import bisect
from xtore.instance.RecordNode cimport hashDJB
from xtore.BaseType cimport i64, i32, u32

cdef class ConsistentHashing:
	def __init__(self):
		self.ring = {}
		self.sortedKey = []

	cdef addNodeConsistentHashing(self, ConsistentNode nodeConsistent, i64 hashValueConsistent):
		self.ring[hashValueConsistent] = nodeConsistent
		bisect.insort(self.sortedKey, hashValueConsistent)

	cdef removeNodeConsistentHashing(self, ConsistentNode nodeConsistent, i64 hashValueConsistent):
		if hashValueConsistent in self.ring:
				del self.ring[hashValueConsistent]
				self.sortedKey.remove(hashValueConsistent)

	cdef ConsistentNode getNodeConsistentHashing(self, i64 hashValueConsistent):
		cdef i32 indexFind = bisect.bisect_right(self.sortedKey, hashValueConsistent)

		if not self.sortedKey:
			return None

		if indexFind == len(self.sortedKey):
			indexFind = 0
		return self.ring[self.sortedKey[indexFind]]