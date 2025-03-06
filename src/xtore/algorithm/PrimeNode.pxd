from xtore.BaseType cimport u16, i32

cdef class PrimeNode:
	cdef i32 id
	cdef str host
	cdef u16 port
	cdef i32 layer
	cdef list children
	cdef i32 isMaster