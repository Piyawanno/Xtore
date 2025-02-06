from xtore.BaseType cimport u16

cdef class ServerService :
	cdef dict config
	cdef str host
	cdef u16 port
	cdef object loop
