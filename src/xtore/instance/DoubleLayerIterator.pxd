from xtore.BaseType cimport i32, i64
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.RecordPageNode cimport RecordPageNode
from xtore.common.Buffer cimport Buffer

ctypedef struct DoubleLayerIndex:
	i32 offset
	i32 index
	i32 subIndex
	i64 upperPosition
	i64 lowerPosition

cdef inline str getIndexString(DoubleLayerIndex index):
	return f'<DoubleLayerIndex o={index.offset} i={index.index} s={index.subIndex} up={index.upperPosition} lp={index.lowerPosition}>'

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
	cdef bint getNext(self, RecordPageNode entry)
	cdef bint move(self, DoubleLayerIndex *index)
	cdef i64 getLowerPosition(self, i32 index)
	cdef setPosition(self, DoubleLayerIndex index)

