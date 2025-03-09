from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16, i32, i64
from xtore.algorithm.PrimeNode cimport PrimeNode

cdef class PrimeRing:
	cdef list primeRingConfig
	cdef list primeNumbers
	cdef i32 replicaNumber
	cdef list[PrimeNode] nodes
	cdef i32 nodeNumber
	cdef i32 layerNumber

	cdef loadData(self, list config)
	cdef initPrimeRing(self)
	cdef list[PrimeNode] getStorageUnit(self, i64 hashKey)


