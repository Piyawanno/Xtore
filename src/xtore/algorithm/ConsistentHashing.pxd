from xtore.BaseType cimport i64, i32, u32
from xtore.instance.RecordNode cimport hashDJB
from xtore.algorithm.ConsistentNode cimport ConsistentNode

cdef class ConsistentHashing:
    #cdef u32 numReplica
    cdef dict ring
    cdef list sortedKey

    cdef addNodeConsistentHashing(self, ConsistentNode nodeConsistent)
    cdef removeNodeConsistentHashing (self, ConsistentNode nodeConsistent)
    cdef getNodeConsistentHashing (self, char *keyConsistent)
