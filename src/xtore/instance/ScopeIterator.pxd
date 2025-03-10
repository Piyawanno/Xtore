from xtore.BaseType cimport i32, u64
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.instance.RecordNode cimport RecordNode

cdef class ScopeIterator (BasicIterator):
	cdef ScopeTreeStorage storage
	cdef i32 depth
	cdef i32 pageBufferSize
	cdef char *buffer
	cdef Buffer *streamList
	cdef u64 *pagePosition
	cdef i32 *index
	cdef bint hasNext

	cdef i32 currentIndex
	cdef i32 currentPosition
	cdef i32 currentDepth
	cdef u64 currentPage
	cdef Buffer *currentStream

	cdef bint moveNextPage(self)
	cdef bint moveBackPage(self)
	cdef bint moveNext(self, Buffer *stream, i32 depth, i32 start)
	cdef bint moveBack(self, Buffer *stream, i32 depth, i32 start)
	cdef getHead(self)
	cdef getTail(self)