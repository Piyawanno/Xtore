from xtore.BaseType cimport u16, i32

cdef class ConsistentNode:
	cdef public i32 id
	cdef public str host
	cdef public u16 port