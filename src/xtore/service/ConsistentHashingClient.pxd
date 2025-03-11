from xtore.algorithm.ConsistentHashing cimport ConsistentHashing
from xtore.algorithm.ConsistentNode cimport ConsistentNode
from xtore.service.DatabaseClient cimport DatabaseClient

cdef class ConsistentHashingClient (DatabaseClient) :
	cdef list nodeList
	cdef ConsistentHashing primeRing
	cdef list[ConsistentNode] consistentNodeList
