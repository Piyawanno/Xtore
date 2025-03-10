from xtore.algorithm.PrimeRing cimport PrimeRing
from xtore.algorithm.PrimeNode cimport PrimeNode
from xtore.common.Buffer cimport Buffer
from xtore.protocol.RecordNodeProtocol cimport DatabaseOperation, InstanceType
from xtore.service.DatabaseClient cimport DatabaseClient

cdef class PrimeRingClient (DatabaseClient) :
	cdef list nodeList
	cdef PrimeRing primeRing
	cdef list[PrimeNode] storageUnit

	cdef encodeData(self, DatabaseOperation method, InstanceType instanceType, list data)