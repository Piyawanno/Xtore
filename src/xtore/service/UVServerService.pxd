from xtore.BaseType cimport u16

cdef class UVServerService :
	cdef dict config
	cdef str host
	cdef u16 port
