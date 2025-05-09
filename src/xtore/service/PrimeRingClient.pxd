from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.service.DatabaseClient cimport DatabaseClient
from xtore.service.PrimeRingErrorHandler cimport PrimeRingErrorHandler

cdef class PrimeRingClient (DatabaseClient) :
	cdef dict nodeList
	cdef PrimeRing primeRing
	cdef dict storageUnit
	cdef PrimeRingErrorHandler handler
