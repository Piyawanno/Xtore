from xtore.BaseType cimport u16

cdef class Client :
	cdef dict config
	cdef str host
	cdef u16 port
	cdef bint connected
	cdef object reader
	cdef object writer