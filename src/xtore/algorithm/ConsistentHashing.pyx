import bisect
from xtore.instance.RecordNode cimport hashDJB
from xtore.BaseType cimport i64, i32, u32

cdef class ConsistentHashing:
    def __init__(self):
        #self.numReplica = numReplica
        self.ring = {}
        self.sortedKey = []

    cdef addNodeConsistentHashing(self, ConsistentNode nodeConsistent):
        cdef hashValueConsistent = self.hashDJB(nodeConsistent)
        self.ring[hashValueConsistent] = nodeConsistent
        bisect.insort(self.sortedKey, hashValueConsistent)

    cdef removeNodeConsistentHashing(self, ConsistentNode nodeConsistent):
        cdef hashValueConsistent = self.hashDJB(nodeConsistent)
        if hashValueConsistent in self.ring:
                del self.ring[hashValueConsistent]
                self.sortedKey.remove(hashValueConsistent)

    cdef getNodeConsistentHashing(self, char *keyConsistent):
        cdef hashValueConsistent = self.hashDJB(keyConsistent)
        indexFind = bisect.bisect_right(self.sortedKey, hashValueConsistent)
        if indexFind == len(self.sortedKey):
            indexFind = 0
        return self.ring[self.sortedKey[indexFind]]
