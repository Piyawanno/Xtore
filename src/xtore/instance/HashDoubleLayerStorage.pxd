from xtore.BaseType cimport i32, i64
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.RecordPageNode cimport RecordPageNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.Page cimport Page
from xtore.instance.PageSearch cimport PageSearch
from xtore.instance.DoubleLayerIterator cimport DoubleLayerIndex
from xtore.instance.DoubleLayerRangeResult cimport DoubleLayerRangeResult
from xtore.common.Buffer cimport Buffer

cdef class HashDoubleLayerStorage(HashStorage):
	cdef Buffer upperPageStream
	cdef Buffer entryStream
	cdef Buffer searchStream
	cdef LinkedPageStorage itemStorage
	cdef LinkedPage upper
	cdef LinkedPage upperPage
	cdef Page lower
	cdef Page lowerPage

	cdef RecordPageNode tail
	cdef RecordPageNode existing
	cdef PageSearch upperSearch
	cdef PageSearch lowerSearch

	# NOTE Append entry to the end of the list without order checking.
	# This method should be regularly called.
	cdef appendPageNode(self, RecordPageNode entry)
	# NOTE Insert entry to the list with order checking.
	# This method is not optimal due to memory move and should be called
	# only by exception.
	cdef insertPageNode(self, RecordPageNode entry)
	cdef RecordPageNode getPageNode(self, RecordPageNode reference)
	cdef DoubleLayerRangeResult getRange(self, RecordPageNode start, RecordPageNode end)
	cdef RecordPageNode getLatestPageNode(self, RecordPageNode reference)
	cdef RecordPageNode getFirstPageNode(self, RecordPageNode reference)
	cdef insertLower(self, DoubleLayerIndex target, Buffer *stream)
	cdef writeLowerHeadToUpper(self, DoubleLayerIndex target, Buffer *lower, LinkedPage upperPage)
	cdef split(self, DoubleLayerIndex target, Buffer *upper, Buffer *lower)
	cdef splitTail(self, DoubleLayerIndex target, Buffer *upper, Buffer *lower)
	cdef Page splitLower(self, DoubleLayerIndex target, Buffer *lower)
	cdef DoubleLayerIndex searchInsertPosition(self, RecordPageNode entry, RecordPageNode found)
