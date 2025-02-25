from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16, i32
from xtore.service.Node cimport Node

cdef class PrimeRing:
	cdef dict config
	cdef list primeRingConfig
	cdef list primeNumbers
	cdef i32 replicaNumber
	cdef list nodes
	cdef i32 nodeNumber

	cdef getConfig(self)
	cdef loadData(self)
	cdef initPrimeRing(self)
	cdef setConfig(self)
	cdef dict getNodeForSet(self, char * key)
	cdef dict getNodeForGet(self, i32 index)


