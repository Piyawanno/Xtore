from xtore.BaseType cimport i64, i32, u32
from xtore.instance.RecordNode cimport hashDJB
from xtore.algorithm.ConsistentNode cimport ConsistentNode

cdef class ConsistentHashing:
	#cdef i32 RInConsistent
	cdef dict ring
	cdef list sortedKey

	cdef addNodeConsistentHashing(self, ConsistentNode nodeConsistent, i64 hashValueConsistent)
	cdef removeNodeConsistentHashing (self, ConsistentNode nodeConsistent, i64 hashValueConsistent)
	cdef ConsistentNode getNodeConsistentHashing (self, i64 hashValueConsistent)
