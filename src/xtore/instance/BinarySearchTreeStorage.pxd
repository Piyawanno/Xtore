from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.RecordNode cimport RecordNode

cdef class BinarySearchTreeStorage (BasicStorage):
	cdef i64 rootPosition
	cdef i64 rootNodePosition
	cdef bint isCreated

	cdef Buffer stream
	cdef Buffer headerStream

	cdef RecordNode comparingNode
