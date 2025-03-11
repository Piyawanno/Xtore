from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.service.DatabaseClient cimport DatabaseClient

cdef class PrimeRingClient (DatabaseClient) :
	cdef list nodeList
	cdef PrimeRing primeRing
	cdef list[PrimeNode] storageUnit
