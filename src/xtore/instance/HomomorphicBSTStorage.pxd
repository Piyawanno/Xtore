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

	cdef list getRangeData(self, RecordNode dataSet, int low, int high)
	cdef list getGreater(self, RecordNode dataSet, int threshold)
	cdef list getLess(self, RecordNode dataSet, int threshold)
	
	cdef void inOrderLessSearch(self, i64 position, RecordNode dataSet, int threshold, list resultList)
	cdef void inOrderGreaterSearch(self, i64 position, RecordNode dataSet, int threshold, list resultList)
	cdef void collectSubTree(self, i64 position, list result)

	cdef void collectFromLow(self, i64 position, RecordNode dataSet, int low, list resultList)
	cdef void collectFromHigh(self, i64 position, RecordNode dataSet, int high, list resultList)
