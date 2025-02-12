from xtore.protocol.AsyncProtocol cimport AsyncProtocol
from xtore.common.Buffer cimport Buffer

cdef class ReplicaProtocol(AsyncProtocol) :
	cdef Buffer stream
	
	cdef str getResourcePath(self)