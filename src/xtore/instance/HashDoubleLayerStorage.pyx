from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.RecordPageNode cimport RecordPageNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.Page cimport Page, PAGE_HEADER_SIZE
from xtore.instance.LinkedPage cimport LinkedPage, LINKED_PAGE_HEADER_SIZE
from xtore.instance.PageSearch cimport PageSearch
from xtore.instance.DoubleLayerRangeResult cimport DoubleLayerRangeResult
from xtore.instance.DoubleLayerIterator cimport DoubleLayerIterator, DoubleLayerIndex, getIndexString
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.TimeUtil cimport getMicroTime
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer, getBuffer, setBuffer, checkBufferSize
from xtore.BaseType cimport i32, i64

from libc.stdlib cimport malloc
from libc.string cimport memcpy
from posix.strings cimport bzero

import sys

cdef i32 BUFFER_SIZE = 64

cdef showOverPage(StreamIOHandler io, i32 number):
	cdef Page ttp = Page(io, 32768, 16)
	cdef i64 ttt = io.getTail()
	if ttt > 7827669:
		ttp.readHeader(7827669)
		if ttp.n > 2048:
			print(number, ttp)
			sys.exit(0)

cdef class HashDoubleLayerStorage(HashStorage):
	def __init__(self, StreamIOHandler io, CollisionMode mode, PageSearch upperSearch, PageSearch lowerSearch):
		HashStorage.__init__(self, io, mode)
		self.upperSearch = upperSearch
		self.upper = self.upperSearch.page
		self.upperPage = LinkedPage(self.io, self.upper.pageSize, self.upper.itemSize)
		self.lowerSearch = lowerSearch
		self.lower = self.lowerSearch.page
		self.lowerPage = Page(self.io, self.lower.pageSize, self.lower.itemSize)
		self.itemStorage = LinkedPageStorage(self.io, self.upper.pageSize, self.upper.itemSize)

		self.existing = self.createNode()
		self.tail = self.createNode()

		cdef i32 bufferSize = max(self.upper.itemSize, self.lower.itemSize)
		initBuffer(&self.upperPageStream, <char *> malloc(bufferSize), bufferSize)
		initBuffer(&self.searchStream, <char *> malloc(bufferSize), bufferSize)
		initBuffer(&self.entryStream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
	
	def __dealloc__(self):
		releaseBuffer(&self.upperPageStream)
		releaseBuffer(&self.searchStream)
		releaseBuffer(&self.entryStream)
	
	cdef appendPageNode(self, RecordPageNode entry):
		cdef RecordPageNode existing = None
		if entry.position < 0:
			existing = self.get(entry, self.existing)
			if existing is not None:
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
			entry.itemPosition = self.lower.position + self.lower.tail
			self.lower.appendValue(self.entryStream.buffer)
			self.upperPageStream.position = 0
			entry.writeUpperItem(&self.upperPageStream, pagePosition)
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
		entry.itemPosition = self.lower.position + self.lower.tail
		cdef bint isAppended = self.lower.appendValue(self.entryStream.buffer)
		if not isAppended:
			pagePosition = self.lower.create()
			entry.itemPosition = self.lower.position + self.lower.tail
			self.lower.appendValue(self.entryStream.buffer)
			self.upperPageStream.position = 0
			entry.writeUpperItem(&self.upperPageStream, pagePosition)
			self.itemStorage.appendValue(self.upperPageStream.buffer)
		
	cdef insertPageNode(self, RecordPageNode entry):
		cdef RecordPageNode existing = None
		cdef LinkedPage tail
		cdef i64 pagePosition
		if entry.position < 0:
			existing = self.get(entry, self.existing)
			if existing is not None:
				entry.position = existing.position
				entry.pagePosition = existing.pagePosition
		else:
			existing = entry
		
		if existing is not None and existing.pagePosition != self.itemStorage.rootPosition:
			self.itemStorage.readHeader(entry.pagePosition)
			tail = self.itemStorage.tail
			tail.read(self.itemStorage.tailPosition)
			pagePosition = (<i64*> (tail.stream.buffer+(tail.tail-tail.itemSize)))[0]
			if self.lower.position != pagePosition: self.lower.read(pagePosition)
			self.lower.stream.position = self.lower.tail - self.lower.itemSize
			self.tail.readItem(&self.lower.stream)

		if existing is None or entry.comparePage(self.tail) > 0:
			tail = self.itemStorage.tail
			if tail.n > 0:
				pagePosition = (<i64*> (tail.stream.buffer+(tail.tail-tail.itemSize)))[0]
				if self.lower.position != pagePosition:
					self.lower.read(pagePosition)
			self.appendPageNode(entry)
			self.tail.copyKey(entry)
			self.tail.copyPageKey(entry)
			return

		cdef DoubleLayerIndex target = self.searchInsertPosition(entry, existing)
		self.upper = <LinkedPage> self.upperSearch.page
		self.lower = self.lowerSearch.page
		cdef bint hasSpace = (self.lower.pageSize - self.lower.tail) > self.lower.itemSize
		if hasSpace:
			self.insertLower(target, &self.searchStream)
			return
		hasSpace = (self.upper.pageSize - self.upper.tail) > self.upper.itemSize
		if hasSpace:
			self.splitTail(target, &self.upperPageStream, &self.searchStream)
		else:
			self.split(target, &self.upperPageStream, &self.searchStream)
		

	cdef RecordPageNode getPageNode(self, RecordPageNode reference):
		cdef RecordPageNode found = self.get(reference, self.existing)
		if found is None: return None
		reference.writeUpperItem(&self.searchStream, -1)
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

	cdef DoubleLayerRangeResult getRange(self, RecordPageNode start, RecordPageNode end):
		cdef RecordPageNode found = self.get(start, self.existing)
		if found is None: return None

		self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.headPosition)
		self.upperSearch.setPage(self.upper)
		self.upperSearch.readPosition(self.itemStorage.rootPosition, self.itemStorage.lastUpdate)
		
		start.writeUpperItem(&self.searchStream, -1)
		self.searchStream.position = 0
		self.upper.read(found.pagePosition)
		cdef i32 startUpper = self.upperSearch.getGreaterEqualPage(&self.searchStream)
		if startUpper < 0: startUpper = 0
		
		start.writeItem(&self.searchStream)
		self.searchStream.position = 0
		cdef i64 startPosition = self.upper.position
		cdef i32 index = startUpper if startUpper == 0 else startUpper - 1
		cdef i32 offset = self.upperSearch.position[index]
		cdef i64 lowerPosition = (<i64 *> (self.upper.stream.buffer+offset))[0]
		self.lower.read(lowerPosition)
		cdef i32 startLower = self.lowerSearch.getGreaterEqual(&self.searchStream)
		if startLower < 0:
			if startUpper+1 < self.upper.n:
				startUpper += 1
				startLower = 0
			elif self.upper.next > 0:
				self.upper.read(self.upper.next)
				startUpper = 0
				startLower = 0
			else:
				return None
		
		end.writeUpperItem(&self.searchStream, -1)
		self.searchStream.position = 0
		cdef i32 endUpper = self.upperSearch.getLessEqualPage(&self.searchStream)
		if endUpper < 0: endUpper = 0
		
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
		result.endSubIndex = endLower + 1
		return result

	cdef RecordPageNode getLatestPageNode(self, RecordPageNode reference):
		cdef RecordPageNode found = self.get(reference, self.existing)
		if found is None: return None
		self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.tailPosition)
		cdef i32 offset = self.upper.tail - self.upper.itemSize
		if self.upper.n == 0: return
		cdef i64 lowerPosition = (<i64 *> (self.upper.stream.buffer+offset))[0]
		self.lower.read(lowerPosition)
		if self.lower.n == 0: return
		offset = self.lower.tail - self.lower.itemSize
		self.lower.stream.position = offset
		found.readItem(&self.lower.stream)
		return found
	
	cdef RecordPageNode getFirstPageNode(self, RecordPageNode reference):
		cdef RecordPageNode found = self.get(reference, self.existing)
		if found is None: return None
		self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.headPosition)
		if self.upper.n == 0: return
		cdef i64 lowerPosition = (<i64 *> (self.upper.stream.buffer+LINKED_PAGE_HEADER_SIZE))[0]
		cdef i32 dateID = (<i64 *> (self.upper.stream.buffer+LINKED_PAGE_HEADER_SIZE+8))[0]
		self.lower.read(lowerPosition)
		if self.lower.n == 0: return
		self.lower.stream.position = PAGE_HEADER_SIZE
		found.readItem(&self.lower.stream)
		return found
	
	cdef insertLower(self, DoubleLayerIndex target, Buffer *lower):
		cdef i32 itemSize = self.lower.itemSize
		cdef i32 offset = self.lowerSearch.position[target.subIndex]
		cdef i32 length = self.lower.tail - offset
		cdef Buffer *stream = &self.lower.stream
		cdef LinkedPage upperPage = self.upper
		if self.upper.position == self.itemStorage.tail.position:
			upperPage = self.itemStorage.tail
		memcpy(stream.buffer+offset+itemSize, stream.buffer+offset, length)
		memcpy(stream.buffer+offset, lower.buffer, itemSize)
		self.io.seek(target.lowerPosition+offset)
		self.io.writeOffset(stream, offset, length+itemSize)
		self.lower.n += 1
		self.lower.tail += itemSize
		self.lower.writeHeader()
		if target.subIndex == 0:
			self.writeLowerHeadToUpper(target, lower, upperPage)
			self.itemStorage.lastUpdate = getMicroTime()
			self.itemStorage.writeHeader()
	
	cdef writeLowerHeadToUpper(self, DoubleLayerIndex target, Buffer *lower, LinkedPage upperPage):
		lower.position = 0
		self.existing.readItem(lower)
		upperOffset = self.upperSearch.position[target.index]
		upperPage.stream.position = upperOffset
		self.existing.writeUpperItem(&upperPage.stream, target.lowerPosition)
		self.io.seek(target.upperPosition+upperOffset)
		self.io.writeOffset(&upperPage.stream, upperOffset, upperPage.itemSize)
		
	cdef split(self, DoubleLayerIndex target, Buffer *upper, Buffer *lower):
		cdef i32 itemSize = self.upper.itemSize
		# NOTE Split @target.index -> split page must be stored @target.index+1
		cdef Page lowerPage = self.splitLower(target, lower)
		# NOTE Consider replacing self.upperPage with self.itemStorage.tail.
		cdef LinkedPage split
		cdef bint isTail = self.upper.position == self.itemStorage.tail.position
		if isTail: split = self.itemStorage.tail
		else: split = self.upperPage

		lowerPage.stream.position = PAGE_HEADER_SIZE
		self.existing.readItem(&lowerPage.stream)
		split.create()
		self.upper.read(target.upperPosition)

		cdef i32 n = self.upper.n // 2
		split.n = self.upper.n  - n
		self.upper.n = n
		cdef i32 offset = LINKED_PAGE_HEADER_SIZE+n*itemSize
		cdef i32 length = split.n*itemSize
		cdef i32 existingLength = offset
		cdef Buffer *stream = &self.upper.stream

		memcpy(split.stream.buffer+LINKED_PAGE_HEADER_SIZE, stream.buffer+offset, length)
		bzero(stream.buffer+offset, length)
		cdef LinkedPage targetPage
		cdef i32 index = target.index+1
		if target.index >= n:
			targetPage = split
			length += itemSize
			index = index - n
		else:
			targetPage = self.upper
			existingLength += itemSize

		cdef i32 targetOffset = LINKED_PAGE_HEADER_SIZE + itemSize*index
		cdef i32 targetLength = itemSize*(targetPage.n - index)
		stream = &targetPage.stream
		if targetLength > 0: memcpy(stream.buffer+targetOffset+itemSize, stream.buffer+targetOffset, targetLength)
		
		stream.position = targetOffset
		self.existing.writeUpperItem(stream, lowerPage.position)
		targetPage.n += 1

		if target.subIndex == 0: self.writeLowerHeadToUpper(target, lower, self.upper)

		cdef LinkedPage next
		if self.upper.next > 0:
			if self.upper.next == self.itemStorage.tailPosition: next = self.itemStorage.tail
			else: next = LinkedPage(self.io, self.upper.pageSize, self.upper.itemSize)
			next.readHeader(self.upper.next)
			next.previous = split.position
			next.writeHeader()
			
		split.next = self.upper.next
		self.upper.tail = existingLength
		self.upper.next = split.position
		self.upper.writeHeaderBuffer()
		self.io.seek(self.upper.position)
		self.upper.stream.position = existingLength
		self.io.write(&self.upper.stream)
		
		split.tail = LINKED_PAGE_HEADER_SIZE + length
		split.previous = self.upper.position
		split.writeHeaderBuffer()
		self.io.seek(split.position)
		split.stream.position = split.tail
		self.io.write(&split.stream)

		if isTail: self.itemStorage.tailPosition = split.position
		self.itemStorage.lastUpdate = getMicroTime()
		self.itemStorage.writeHeader()

		
	cdef splitTail(self, DoubleLayerIndex target, Buffer *upper, Buffer *lower):
		cdef i32 itemSize = self.upper.itemSize
		cdef Page lowerPage = self.splitLower(target, lower)
		# NOTE Split @target.index -> split page must be stored @target.index+1
		cdef i32 index = target.index + 1
		cdef LinkedPage page
		if target.upperPosition == self.itemStorage.tailPosition:
			page = self.itemStorage.tail
		else:
			self.upper.read(target.upperPosition)
			page = self.upper
		
		if target.subIndex == 0: self.writeLowerHeadToUpper(target, lower, page)

		lowerPage.stream.position = PAGE_HEADER_SIZE
		self.existing.readItem(&lowerPage.stream)

		cdef i32 offset = LINKED_PAGE_HEADER_SIZE + itemSize*index
		cdef i32 length = itemSize*(self.upper.n - index)
		cdef Buffer *stream = &page.stream
		if length > 0: memcpy(stream.buffer+offset+itemSize, stream.buffer+offset, length)

		stream.position = offset
		self.existing.writeUpperItem(stream, lowerPage.position)
		page.n += 1
		page.tail += itemSize
		self.io.seek(page.position+offset)
		self.io.writeOffset(stream, offset, length+itemSize)
		page.writeHeader()
		self.itemStorage.lastUpdate = getMicroTime()
		self.itemStorage.writeHeader()

	cdef Page splitLower(self, DoubleLayerIndex target, Buffer *lower):
		cdef i32 itemSize = self.lower.itemSize
		cdef Page split = self.lowerPage
		split.create()
		self.lower.read(target.lowerPosition)
		cdef i32 n = self.lower.n // 2
		split.n = self.lower.n  - n
		self.lower.n = n
		cdef i32 offset = PAGE_HEADER_SIZE+n*itemSize
		cdef i32 length = split.n*itemSize
		cdef i32 existingLength = offset
		cdef Buffer *stream = &self.lower.stream
		memcpy(split.stream.buffer+PAGE_HEADER_SIZE, stream.buffer+offset, length)
		bzero(stream.buffer+offset, length)
		cdef Page targetPage
		if target.subIndex >= n:
			targetPage = split
			length += itemSize
			target.subIndex = target.subIndex-n
		else:
			targetPage = self.lower
			existingLength += itemSize

		cdef i32 targetOffset = PAGE_HEADER_SIZE + itemSize*target.subIndex
		cdef i32 targetLength = itemSize*(targetPage.n - target.subIndex)
		stream = &targetPage.stream
		if targetLength > 0:
			memcpy(stream.buffer+targetOffset+itemSize, stream.buffer+targetOffset, targetLength)
		memcpy(stream.buffer+targetOffset, lower.buffer, itemSize)
		targetPage.n += 1

		self.lower.tail = existingLength
		self.lower.writeHeaderBuffer()
		self.io.seek(self.lower.position)
		self.lower.stream.position = existingLength
		self.io.write(&self.lower.stream)
		
		split.tail = PAGE_HEADER_SIZE + length
		split.writeHeaderBuffer()
		self.io.seek(split.position)
		split.stream.position = PAGE_HEADER_SIZE + length
		self.io.write(&split.stream)
		return split

	cdef DoubleLayerIndex searchInsertPosition(self, RecordPageNode entry, RecordPageNode found):
		cdef DoubleLayerIndex target
		if self.itemStorage.rootPosition != found.pagePosition:
			self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.headPosition)
		self.upperSearch.setPage(self.upper)
		self.upperSearch.readPosition(self.itemStorage.rootPosition, self.itemStorage.lastUpdate)
		self.upperPageStream.position = 0
		entry.writeUpperItem(&self.upperPageStream, -1)
		self.upperPageStream.position = 0
		target.index = self.upperSearch.getGreaterEqualPage(&self.upperPageStream)
		cdef bint isHead = target.index <= 0
		target.index = 0 if target.index <= 0 else target.index-1
		target.upperPosition = self.upper.position
		cdef i32 position = self.upperSearch.position[target.index]

		cdef i64 lowerPosition = (<i64 *> (self.upper.stream.buffer + position))[0]
		self.lower.read(lowerPosition)
		self.searchStream.position = 0
		entry.writeItem(&self.searchStream)
		self.searchStream.position = 0
		target.subIndex = self.lowerSearch.getGreaterEqual(&self.searchStream)
		if target.subIndex < 0: target.subIndex = 0
		if target.subIndex == 0 and not isHead:
			target.subIndex = self.lower.n
		target.offset = self.lowerSearch.position[target.subIndex]
		target.lowerPosition = self.lower.position
		return target
