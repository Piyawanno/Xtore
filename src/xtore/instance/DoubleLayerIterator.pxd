from xtore.BaseType cimport i32, i64
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.HashPageNode cimport HashPageNode
from xtore.common.Buffer cimport Buffer

cdef class DoubleLayerIterator:
	cdef LinkedPageStorage storage
	cdef LinkedPage upper
	cdef Page lower
	cdef Buffer entryStream

	cdef i32 *upperPosition
	cdef i32 *lowerPosition

	cdef i32 currentIndex
	cdef i32 currentSubIndex

	cdef start(self, i64 headPosition)
	cdef bint getNext(self, HashPageNode entry)
	cdef i64 getLowerPosition(self, i32 index)

