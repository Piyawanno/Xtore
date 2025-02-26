import bisect
from xtore.instance.RecordNode cimport hashDJB
from xtore.BaseType cimport i64, i32, u32

cdef class ConsistentHashing:
    def __init__(self):
        #self.numReplica = numReplica
        self.ring = {}
        self.sortedKey = []

    cdef addNodeConsistentHashing(self, ConsistentNode nodeConsistent):
        # ✅ ใช้ host หรือ id ของ Node เป็น key
        cdef bytes keyBytes = nodeConsistent.host.encode('utf-8')
        cdef u32 keyLen = len(keyBytes)

        # ✅ เรียก hashDJB โดยส่งค่าเป็น (char*, u32)
        cdef i64 hashValueConsistent = hashDJB(keyBytes, keyLen)
        #cdef hashValueConsistent = self.hashDJB(nodeConsistent)
        self.ring[hashValueConsistent] = nodeConsistent
        bisect.insort(self.sortedKey, hashValueConsistent)

    cdef removeNodeConsistentHashing(self, ConsistentNode nodeConsistent):
        cdef bytes keyBytes = nodeConsistent.host.encode('utf-8')
        cdef u32 keyLen = len(keyBytes)
        cdef i64 hashValueConsistent = hashDJB(keyBytes, keyLen)
        if hashValueConsistent in self.ring:
                del self.ring[hashValueConsistent]
                self.sortedKey.remove(hashValueConsistent)

    cdef getNodeConsistentHashing(self, char *keyConsistent):
        cdef i64 hashValueConsistent = hashDJB(keyConsistent, len(keyConsistent))
        indexFind = bisect.bisect_right(self.sortedKey, hashValueConsistent)
        if indexFind == len(self.sortedKey):
            indexFind = 0
        return self.ring[self.sortedKey[indexFind]]
