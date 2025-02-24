from xtore.BaseType cimport u16, i32

cdef class ConsistentNode:
	cdef i32 id
	cdef str host
	cdef u16 port
	cdef list replicas