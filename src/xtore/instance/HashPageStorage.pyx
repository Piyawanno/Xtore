from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.RecordPageNode cimport RecordPageNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.PageSearch cimport PageSearch
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport initBuffer, releaseBuffer, getBuffer
from xtore.BaseType cimport i32, i64

from libc.stdlib cimport malloc

cdef i32 BUFFER_SIZE = 64

cdef class HashPageStorage(HashStorage):
	def __init__(self, StreamIOHandler io, CollisionMode mode, PageSearch search):
		HashStorage.__init__(self, io, mode)
		self.search = search
		self.page = self.search.page
		self.itemStorage = LinkedPageStorage(self.io, self.page.pageSize, self.page.itemSize)

		self.existing = self.createNode()
		cdef i32 bufferSize = self.page.itemSize
		initBuffer(&self.searchStream, <char *> malloc(bufferSize), bufferSize)
		initBuffer(&self.entryStream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self):
		releaseBuffer(&self.searchStream)
		releaseBuffer(&self.entryStream)
		
	cdef appendPageNode(self, RecordPageNode entry):
		cdef RecordPageNode existing = None
		if entry.position < 0:
			existing = self.get(entry, self.existing)
			entry.position = existing.position
			entry.pagePosition = existing.pagePosition
		else:
			existing = entry
		cdef LinkedPage tail
		self.entryStream.position = 0
		entry.writeItem(&self.entryStream)
		cdef i64 pagePosition
		if existing is None:
			self.itemStorage.create()
			# print(470)
			self.itemStorage.appendValue(self.entryStream.buffer)
			entry.pagePosition = self.itemStorage.rootPosition
			self.set(entry)
			return
		if self.itemStorage.rootPosition != entry.pagePosition:
			self.itemStorage.readHeader(entry.pagePosition)
		# print(471)
		self.itemStorage.appendValue(self.entryStream.buffer)
	