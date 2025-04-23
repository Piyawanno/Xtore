from xtore.BaseType cimport i32, i64, byte
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.RecordNode cimport RecordNode


cdef class HomomorphicBSTStorage (BasicStorage):
	cdef i64 rootPosition
	cdef i64 rootNodePosition
	cdef bint isCreated

	cdef Buffer stream
	cdef Buffer headerStream
	cdef RecordNode comparingNode

	cdef list getRangeData(self, RecordNode low, RecordNode high)
	cdef tuple readNode(self, i64 position)
	cdef void collectLess(self, i64 position, RecordNode high, list result)
	cdef void collectGreater(self, i64 position, RecordNode low, list result)
