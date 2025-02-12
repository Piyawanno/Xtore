from xtore.protocol.AsyncProtocol cimport AsyncProtocol

cdef class ListenProtocol (AsyncProtocol):
	cdef bytes message
	cdef object loop
	cdef object responseFuture