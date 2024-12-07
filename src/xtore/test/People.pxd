from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64, u64

cdef i32 PEOPLE_ENTRY_KEY_SIZE
cdef class People (RecordNode):
	cdef u64 ID
	cdef i64 income
	cdef str name
	cdef str surname