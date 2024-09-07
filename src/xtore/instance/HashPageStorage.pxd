from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.HashPageNode cimport HashPageNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.PageSearch cimport PageSearch
from xtore.common.Buffer cimport Buffer

cdef class HashPageStorage(HashStorage):
	cdef Buffer entryStream
	cdef Buffer searchStream
	cdef LinkedPageStorage itemStorage
	cdef LinkedPage page

	cdef HashPageNode existing
	cdef PageSearch search

	cdef appendPageNode(self, HashPageNode entry)
	#cdef HashPageNode getPageNode(self, HashPageNode reference)
	#cdef PageRangeResult getRange(self, HashPageNode start, HashPageNode end)
	#cdef HashPageNode getLatestPageNode(self, HashPageNode reference)