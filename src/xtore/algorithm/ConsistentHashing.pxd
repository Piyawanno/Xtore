from xtore.BaseType cimport i64, i32, u32
from xtore.instance.RecordNode cimport hashDJB
from xtore.algorithm.ConsistentNode cimport ConsistentNode

cdef class ConsistentHashing:
	cdef i32 replicationFactor
	cdef i32 maxNode
	cdef list[ConsistentNode] nodes
	cdef dict nodeMapper
	cdef dict hashTable
	
	cdef loadData(self, dict config)
	cdef i64 generateNodeID(self)
	cdef list[ConsistentNode] getNodeList(self, i64 hashKey)