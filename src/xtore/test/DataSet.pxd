from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64

cdef i32 DATASET_ENTRY_KEY_SIZE

cdef class DataSet(RecordNode):
	cdef i64 address
	cdef i32 index

	# cdef compareHomomorphic(self, RecordNode other)
	cdef str getResourcePath(self)