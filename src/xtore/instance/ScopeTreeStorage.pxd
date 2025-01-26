from xtore.BaseType cimport u64, i32, i64, f128
from xtore.common.Buffer cimport Buffer
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage

ctypedef enum ScopeRootMode:
	LEFT = 1
	MIDDLE = 2
	RIGHT = 3

ctypedef enum OccupationState:
	FREE = 1
	NODE = 2
	PAGE = 3

cdef inline i64 normalizeIndex(ScopeTreeStorage self, i32 maxDepth, f128 key):
	cdef i64 segment = 1
	# NOTE Use for loop to avoid multiplication
	for i in range(maxDepth-1):
		segment = segment << self.potence
	return <i64> (segment*(key - self.min)/self.width)

cdef inline i64 calculateLayerIndex(ScopeTreeStorage self, i32 maxDepth, i64 normalized, i32 layer):
	cdef i64 shifted = normalized
	for i in range(maxDepth-1-layer):
		shifted = shifted >> self.potence
	return shifted & self.modulus

cdef class ScopeTreeStorage (BasicStorage):
	cdef ScopeRootMode rootMode
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

	cdef u64 createPage(self)
	cdef u64 insertNode(self, u64 page, RecordNode node, i32 *depth)
	cdef u64 createParent(self)
	cdef f128 getInitialMinValue(self)
	cdef f128 getInitialMaxValue(self)
	cdef i32 getDepth(self)