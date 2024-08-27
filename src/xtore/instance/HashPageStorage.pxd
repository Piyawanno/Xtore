from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.HashPageNode cimport HashPageNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.Page cimport Page
from xtore.instance.PageSearch cimport PageSearch
from xtore.instance.DoubleLayerRangeResult cimport DoubleLayerRangeResult
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64

cdef class HashPageStorage(HashStorage):
	cdef Buffer upperPageStream
	cdef Buffer entryStream
	cdef Buffer searchStream
	cdef LinkedPageStorage itemStorage
	cdef LinkedPage upper
	cdef Page lower

	cdef HashPageNode existing
	cdef PageSearch upperSearch
	cdef PageSearch lowerSearch

	cdef appendPageNode(self, HashPageNode entry)
	cdef HashPageNode getPageNode(self, HashPageNode reference)
	cdef DoubleLayerRangeResult getRange(self, HashPageNode start, HashPageNode end)