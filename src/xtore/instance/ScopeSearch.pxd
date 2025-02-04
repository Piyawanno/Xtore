from xtore.BaseType cimport i32, u64
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.common.Buffer cimport Buffer
from xtore.instance.ScopeSearchResult cimport ScopeSearchResult
from xtore.instance.RecordNode cimport RecordNode

ctypedef struct NodePosition:
	Buffer *stream
	u64 page
	u64 position
	i32 index
	i32 depth

cdef str getPositionString(NodePosition position)

cdef class ScopeSearch:
	cdef ScopeTreeStorage storage
	cdef StreamIOHandler io
	cdef Buffer positionStream
	cdef RecordNode stored
	cdef i32 depth
	
	cdef ScopeSearchResult getGreater(self, RecordNode reference)
	cdef ScopeSearchResult getGreaterEqual(self, RecordNode reference)

	cdef ScopeSearchResult getLess(self, RecordNode reference)
	cdef ScopeSearchResult getLessEqual(self, RecordNode reference)

	cdef ScopeSearchResult getRange(
		self,
		RecordNode start,
		RecordNode end,
		bint isLowerIncluded,
		bint isUpperIncluded
	)

	cdef bint search(self, RecordNode reference, ScopeSearchResult result, NodePosition *position)