from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64, u64, i32 

cdef i32 PEOPLE_ENTRY_KEY_SIZE
cdef class EncryptedPeople (RecordNode):
	cdef u64 ID
	cdef bytes income
	cdef bytes name
	cdef bytes surname