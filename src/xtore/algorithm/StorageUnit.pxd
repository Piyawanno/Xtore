from xtore.BaseType cimport u16, i32
from xtore.algorithm.PrimeNode cimport PrimeNode

ctypedef enum LoadBalanceMode:
	ROUND_ROBIN = 0
	NO_MASTER_ROUND_ROBIN = 1
	WEIGHT_ROUND_ROBIN = 2
	ADHOC = 3
	NO_MASTER_ADHOC = 4
	WEIGHT_ADHOC = 5

cdef class StorageUnit:
	cdef i32 storageUnitId
	cdef i32 layer
	cdef dict nodes
	cdef i32 parent
	cdef i32 index
	cdef i32 weight
	cdef i32 replicaCounter
	cdef i32 count
	cdef dict loadBalanceMode
	cdef bint isFull

	cdef bint checkFull(self)
	cdef PrimeNode getNextNode(self, LoadBalanceMode mode)
	cdef PrimeNode getRoundRobin(self)
	cdef PrimeNode getNoMasterRoundRobin(self)
	cdef PrimeNode getWeightRoundRobin(self)
	cdef PrimeNode getAdHoc(self)
	cdef PrimeNode getNoMasterAdHoc(self)
	cdef PrimeNode getWeightAdHoc(self)