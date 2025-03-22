from xtore.BaseType cimport u16, i32
from xtore.algorithm.PrimeNode cimport PrimeNode

ctypedef enum Mode:
	RoundRobin = 0
	RoundRobinNoMaster = 1
	WeightRoundRobin = 2
	AdHoc = 3
	AdHocNoMaster = 4
	WeightAdHoc = 5

cdef class StorageUnit:
	cdef i32 storageUnitId
	cdef i32 layer
	cdef list[PrimeNode] nodeList
	cdef list children
	cdef i32 parent
	cdef i32 index
	cdef i32 weight
	cdef i32 replicaCounter
	cdef i32 count
	cdef dict modeFunctionMap

	cdef PrimeNode getNextNode(self, Mode mode)
	cdef PrimeNode roundRobin(self)
	cdef PrimeNode roundRobinNoMaster(self)
	cdef PrimeNode weightRoundRobin(self)
	cdef PrimeNode adHoc(self)
	cdef PrimeNode adHocNoMaster(self)
	cdef PrimeNode weightAdHoc(self)