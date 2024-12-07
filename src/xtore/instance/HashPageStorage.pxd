from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.RecordPageNode cimport RecordPageNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.PageSearch cimport PageSearch
from xtore.common.Buffer cimport Buffer

cdef class HashPageStorage(HashStorage):
	cdef Buffer entryStream
	cdef Buffer searchStream
	cdef LinkedPageStorage itemStorage
	cdef LinkedPage page

	cdef RecordPageNode existing
	cdef PageSearch search
	
	cdef appendPageNode(self, RecordPageNode entry)
	#cdef RecordPageNode getPageNode(self, RecordPageNode reference)
	#cdef PageRangeResult getRange(self, RecordPageNode start, RecordPageNode end)
	#cdef RecordPageNode getLatestPageNode(self, RecordPageNode reference)