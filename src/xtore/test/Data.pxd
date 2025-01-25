from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64, u64

cdef i32 DATA_ENTRY_KEY_SIZE
cdef class Data (RecordNode):
    cdef u64 ID
    cdef dict fields