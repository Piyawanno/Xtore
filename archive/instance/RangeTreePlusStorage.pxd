from xtore.BaseType cimport u64, i32, i64, f128
from xtore.common.Buffer cimport Buffer
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage

cdef class ScopeTreePlusStorage (BasicStorage):
	cdef i64 rootPosition
	cdef i64 rootPagePosition
	cdef bint isCreated

	cdef i32 maxDepth
	cdef i32 pageSize
	cdef i32 pageBufferSize
	cdef i32 potence
	cdef i32 modulus
	cdef f128 min
	cdef f128 max
	cdef f128 width

	cdef Buffer stream
	cdef Buffer headerStream
	cdef Buffer pageStream
	cdef Buffer positionStream

	cdef RecordNode comparingNode

	cdef i64 createPage(self)
	cdef insertNode(self, i64 page, RecordNode node, i32 depth)