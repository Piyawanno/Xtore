from xtore.BaseType cimport i32, i64, byte
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.test.DataSet cimport DataSet


cdef class HomomorphicBSTStorage (BasicStorage):
	cdef i64 rootPosition
	cdef i64 rootNodePosition
	cdef bint isCreated

	cdef Buffer stream
	cdef Buffer headerStream
	cdef RecordNode comparingNode

	cdef list getRangeData(self, RecordNode low, RecordNode high)
	cdef void inOrderRangeSearch(self, i64 position, DataSet low, DataSet high, list resultList)
