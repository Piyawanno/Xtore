from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u16, i32
from xtore.service.Node cimport Node

cdef class PrimeRing:
	cdef dict config
	cdef dict clusterConfig
	cdef list primeNumbers
	cdef i32 replicaNumber
	cdef list nodes
	cdef i32 layer

	cdef getConfig(self)
	cdef initialize(self)
	cdef initPrimeRing(self)
	cdef setConfig(self)


