from xtore.BaseType cimport u16, i32

cdef class PrimeNode:
	cdef str host
	cdef u16 port
	cdef i32 isMaster