from xtore.BaseType cimport i64, i32, u32
from xtore.instance.RecordNode cimport hashDJB
from xtore.algorithm.ConsistentNode cimport ConsistentNode

cdef class ConsistentHashing:
	cdef list consistentConfig 
	cdef list consistentNode
	cdef i32 replicationFactor
	cdef list[ConsistentNode] nodes
	cdef i32 nodeNumber
	cdef i32 maxNode
	cdef dict nodeMap
	
	cdef loadData(self, dict config)
	cdef i64 generateNodeID(self)
	cdef list[ConsistentNode] getNodeList(self, i64 hashKey)