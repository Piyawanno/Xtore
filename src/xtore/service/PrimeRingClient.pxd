from xtore.BaseType cimport u16
from xtore.service.StorageClient cimport StorageClient
from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.algorithm.PrimeNode cimport PrimeNode

cdef class PrimeRingClient :
	cdef dict config
	cdef PrimeRing primeRing
	cdef list[PrimeNode] storageUnit
	cdef bint connected
	cdef object reader
	cdef object writer
	cdef bytes received