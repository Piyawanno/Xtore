from xtore.BaseType cimport u16

cdef class Server :
	cdef dict config
	cdef str host
	cdef u16 port
	cdef object loop
