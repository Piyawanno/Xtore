from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.HashPageNode cimport HashPageNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.PageSearch cimport PageSearch
from xtore.instance.DoubleLayerRangeResult cimport DoubleLayerRangeResult
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport initBuffer, releaseBuffer, getBuffer
from xtore.BaseType cimport i32, i64

from libc.stdlib cimport malloc

cdef i32 BUFFER_SIZE = 64

cdef class HashDoublePageStorage(HashStorage):
	def __init__(self, StreamIOHandler io, PageSearch upperSearch, PageSearch lowerSearch):
		HashStorage.__init__(self, io)
		self.upperSearch = upperSearch
		self.upper = self.upperSearch.page
		self.lowerSearch = lowerSearch
		self.lower = self.lowerSearch.page
		self.itemStorage = LinkedPageStorage(self.io, self.upper.pageSize, self.upper.itemSize)

		self.existing = self.createNode()

		cdef i32 bufferSize = max(self.upper.itemSize, self.lower.itemSize)
		initBuffer(&self.upperPageStream, <char *> malloc(bufferSize), bufferSize)
		initBuffer(&self.searchStream, <char *> malloc(bufferSize), bufferSize)
		initBuffer(&self.entryStream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	
	def __dealloc__(self):
		releaseBuffer(&self.upperPageStream)
		releaseBuffer(&self.searchStream)
		releaseBuffer(&self.entryStream)
		
	cdef appendPageNode(self, HashPageNode entry):
		cdef HashPageNode existing = None
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
			pagePosition = self.lower.create()
			self.lower.appendValue(self.entryStream.buffer)
			self.upperPageStream.position = 0
			entry.writerUpperItem(&self.upperPageStream, pagePosition)
			self.itemStorage.create()
			self.itemStorage.appendValue(self.upperPageStream.buffer)
			entry.pagePosition = self.itemStorage.rootPosition
			self.set(entry)
			return
		if self.itemStorage.rootPosition != entry.pagePosition:
			self.itemStorage.readHeader(entry.pagePosition)
			tail = self.itemStorage.tail
			tail.read(self.itemStorage.tailPosition)
			tail.stream.position = tail.tail-self.upper.itemSize
			pagePosition = (<i64 *> getBuffer(&tail.stream, 8))[0]
			self.lower.read(pagePosition)
		cdef bint isAppended = self.lower.appendValue(self.entryStream.buffer)
		if not isAppended:
			pagePosition = self.lower.create()
			self.lower.appendValue(self.entryStream.buffer)
			self.upperPageStream.position = 0
			entry.writerUpperItem(&self.upperPageStream, pagePosition)
			self.itemStorage.appendValue(self.upperPageStream.buffer)
	
	cdef HashPageNode getPageNode(self, HashPageNode reference):
		cdef HashPageNode found = self.get(reference, self.existing)
		if found is None: return None
		reference.writerUpperItem(&self.searchStream, -1)
		self.searchStream.position = 0
		self.upper.read(found.pagePosition)
		cdef LinkedPage foundPage = <LinkedPage> self.upperSearch.getPageInRange(&self.searchStream)
		if foundPage is None: return None
		cdef i32 index = self.upperSearch.getLessEqualPage(&self.searchStream)
		if index < 0: return None
		cdef i32 position = self.upperSearch.position[index]
		cdef i64 lowerPosition = (<i64 *> (self.upper.stream.buffer + position))[0]
		self.lower.read(lowerPosition)
		reference.writeItem(&self.searchStream)
		self.searchStream.position = 0
		index = self.lowerSearch.getEqual(&self.searchStream)
		if index < 0: return None
		self.lower.stream.position = self.lowerSearch.position[index]
		found.readItem(&self.lower.stream)
		return found

	cdef DoubleLayerRangeResult getRange(self, HashPageNode start, HashPageNode end):
		cdef HashPageNode found = self.get(start, self.existing)
		if found is None: return None

		self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.headPosition)
		self.upperSearch.setPage(self.upper)
		self.upperSearch.readPosition()
		
		start.writerUpperItem(&self.searchStream, -1)
		self.searchStream.position = 0
		self.upper.read(found.pagePosition)
		cdef i32 startUpper = self.upperSearch.getGreaterEqualPage(&self.searchStream)
		if startUpper < 0: return None
		
		start.writeItem(&self.searchStream)
		self.searchStream.position = 0
		cdef i64 startPosition = self.upper.position
		cdef i32 index = startUpper if startUpper == 0 else startUpper - 1
		cdef i32 offset = self.upperSearch.position[index]
		cdef i64 lowerPosition = (<i64 *> (self.upper.stream.buffer+offset))[0]
		self.lower.read(lowerPosition)
		cdef i32 startLower = self.lowerSearch.getGreaterEqual(&self.searchStream)
		if startLower < 0: return None
		
		end.writerUpperItem(&self.searchStream, -1)
		self.searchStream.position = 0
		cdef i32 endUpper = self.upperSearch.getLessEqualPage(&self.searchStream)
		if endUpper < 0: return None
		
		end.writeItem(&self.searchStream)
		self.searchStream.position = 0
		cdef i64 endPosition = self.upper.position
		offset = self.upperSearch.position[endUpper]
		lowerPosition = (<i64 *> (self.upper.stream.buffer+offset))[0]
		self.lower.read(lowerPosition)
		cdef i32 endLower = self.lowerSearch.getLessEqual(&self.searchStream)
		if endLower < 0: return None
		
		cdef DoubleLayerRangeResult result = DoubleLayerRangeResult(self.upper, self.lower)
		result.startPosition = startPosition
		result.startIndex = index
		result.startSubIndex = startLower
		result.endPosition = endPosition
		result.endIndex = endUpper
		result.endSubIndex = endLower
		return result

	cdef HashPageNode getLatestPageNode(self, HashPageNode reference):
		cdef HashPageNode found = self.get(reference, self.existing)
		if found is None: return None
		self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.headPosition)
		cdef i32 offset = self.upper.tail - self.upper.itemSize
		if self.upper.n == 0: return
		cdef i64 lowerPosition = (<i64 *> (self.upper.stream.buffer+offset))[0]
		self.lower.read(lowerPosition)
		if self.lower.n == 0: return
		offset = self.lower.tail - self.lower.itemSize
		self.lower.stream.position = offset
		found.readItem(&self.lower.stream)
		return found