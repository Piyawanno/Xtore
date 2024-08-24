from xtore.instance.HashNode cimport HashNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, u64

cdef i32 PEOPLE_ENTRY_KEY_SIZE
cdef class People (HashNode):
	cdef u64 ID
	cdef str name
	cdef str surname