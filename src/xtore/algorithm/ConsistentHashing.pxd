from xtore.BaseType cimport i64, i32, u32
from xtore.instance.RecordNode cimport hashDJB
from xtore.algorithm.ConsistentNode cimport ConsistentNode

cdef class ConsistentHashing:
	cdef dict ring
	cdef list consistentConfig #ใช้ตอนโหลดจาก config
	cdef list consistentNode
	cdef i32 replicationFactor
	cdef list[ConsistentNode] nodes
	cdef i32 nodeNumber
	cdef i32 maxNode
	
	cdef loadData(self, dict config)
	cdef createNodeId(self)
	cdef initConsistent(self)
	cdef list[ConsistentNode] getNodeList(self, i64 hashKey)

