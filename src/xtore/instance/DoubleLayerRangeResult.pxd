from xtore.BaseType cimport i32, i64
from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.common.Buffer cimport Buffer
from xtore.instance.RecordPageNode cimport RecordPageNode

cdef class DoubleLayerRangeResult:
	cdef LinkedPage upper
	cdef Page lower
	cdef Buffer entryStream

	cdef i32 *upperPosition
	cdef i32 *lowerPosition
	
	cdef i64 startPosition
	cdef i32 startIndex
	cdef i32 startSubIndex
	cdef i64 endPosition
	cdef i32 endIndex
	cdef i32 endSubIndex
	
	cdef i64 currentPosition
	cdef i32 currentIndex
	cdef i32 currentSubIndex

	cdef start(self)
	cdef bint getNext(self, RecordPageNode entry)
	cdef i64 getLowerPosition(self, i32 index)