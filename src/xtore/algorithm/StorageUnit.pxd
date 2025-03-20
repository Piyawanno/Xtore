from xtore.BaseType cimport u16, i32
from xtore.algorithm.PrimeNode cimport PrimeNode

cdef class StorageUnit:
	cdef i32 storageUnitId
	cdef i32 layer
	cdef list[PrimeNode] nodeList
	cdef list children
	cdef i32 index

	cdef PrimeNode roundRobin(self)