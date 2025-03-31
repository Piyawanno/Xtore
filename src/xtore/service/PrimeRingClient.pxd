from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.service.DatabaseClient cimport DatabaseClient

cdef class PrimeRingClient (DatabaseClient) :
	cdef dict nodeList
	cdef PrimeRing primeRing
	cdef dict storageUnit
