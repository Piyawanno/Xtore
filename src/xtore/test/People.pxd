from xtore.instance.HashNode cimport HashNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport u64

cdef class People (HashNode):
	cdef u64 ID
	cdef str name
	cdef str surname