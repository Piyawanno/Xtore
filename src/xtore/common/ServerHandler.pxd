from xtore.BaseType cimport u16

cdef class ServerHandler :
	cdef dict config
	cdef str host
	cdef u16 port
