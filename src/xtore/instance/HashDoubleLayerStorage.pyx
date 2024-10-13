from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.HashPageNode cimport HashPageNode
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

cdef i32 BUFFER_SIZE = 64

cdef class HashDoubleLayerStorage(HashStorage):
	def __init__(self, StreamIOHandler io, CollisionMode mode, PageSearch upperSearch, PageSearch lowerSearch):
		HashStorage.__init__(self, io, mode)
		self.upperSearch = upperSearch
		self.upper = self.upperSearch.page
		self.splittedUpper = LinkedPage(self.io, self.upper.pageSize, self.upper.itemSize)
		self.lowerSearch = lowerSearch
		self.lower = self.lowerSearch.page
		self.splittedLower = Page(self.io, self.lower.pageSize, self.lower.itemSize)
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
	
	cdef appendPageNode(self, HashPageNode entry):
		cdef HashPageNode existing = None
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
	
	cdef insertPageNode(self, HashPageNode entry):
		cdef HashPageNode existing = None
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
			# print(801)
			tail = self.itemStorage.tail
			pagePosition = (<i64*> (tail.stream.buffer+(tail.tail-tail.itemSize)))[0]
			if self.lower.position != pagePosition: self.lower.read(pagePosition)
			self.appendPageNode(entry)
			self.tail.copyKey(entry)
			self.tail.copyPageKey(entry)
			return
		
		cdef DoubleLayerIndex target = self.searchInsertPosition(entry, existing)
		self.upper = <LinkedPage> self.upperSearch.page
		self.lower = self.lowerSearch.page

		cdef bint hasSpace = (self.lower.pageSize - self.lower.tail) > self.lower.itemSize
		if hasSpace:
			# print(802)
			self.insertLower(target, &self.searchStream)
			return
		hasSpace = (self.upper.pageSize - self.upper.tail) > self.upper.itemSize
		if hasSpace:
			# print(803, self.lower)
			self.splitTail(target, &self.upperPageStream, &self.searchStream)
		else:
			# print(804, self.lower)
			self.split(target, &self.upperPageStream, &self.searchStream)

		# print(923, '%'*50)
		# cdef LinkedPage next = LinkedPage(self.io, self.upper.pageSize, self.upper.itemSize)
		# next.readHeader(self.itemStorage.headPosition)
		# while True:
		# 	print(924, next)
		# 	if next.next < 0: break
		# 	next.readHeader(next.next)

	cdef HashPageNode getPageNode(self, HashPageNode reference):
		cdef HashPageNode found = self.get(reference, self.existing)
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

	cdef DoubleLayerRangeResult getRange(self, HashPageNode start, HashPageNode end):
		cdef HashPageNode found = self.get(start, self.existing)
		if found is None: return None

		self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.headPosition)
		self.upperSearch.setPage(self.upper)
		self.upperSearch.readPosition(self.itemStorage.lastUpdate)
		
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
		if startLower < 0: return None
		
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
	
	cdef insertLower(self, DoubleLayerIndex target, Buffer *lower):
		cdef i32 itemSize = self.lower.itemSize
		cdef i32 offset = self.lowerSearch.position[target.subIndex]
		cdef i32 length = self.lower.tail - offset
		cdef Buffer *stream = &self.lower.stream
		cdef LinkedPage upperPage = self.upper
		if self.upper.position == self.itemStorage.tail.position:
			upperPage = self.itemStorage.tail
		# print(700, getIndexString(target))
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
		# print(701, upperOffset, self.upper)
		upperPage.stream.position = upperOffset
		self.existing.writeUpperItem(&upperPage.stream, target.lowerPosition)
		self.io.seek(target.upperPosition+upperOffset)
		self.io.writeOffset(&upperPage.stream, upperOffset, upperPage.itemSize)
		# print(702, (<i32 *> (upperPage.stream.buffer+32))[0])

	
	cdef split(self, DoubleLayerIndex target, Buffer *upper, Buffer *lower):
		cdef i32 itemSize = self.upper.itemSize
		# NOTE Splitt @target.index -> splitted page must be stored @target.index+1
		cdef Page splittedLower = self.splitLower(target, lower)
		# NOTE Consider replacing self.splittedUpper with self.itemStorage.tail.
		cdef LinkedPage splitted
		cdef bint isTail = self.upper.position == self.itemStorage.tail.position
		if isTail: splitted = self.itemStorage.tail
		else: splitted = self.splittedUpper

		splittedLower.stream.position = PAGE_HEADER_SIZE
		self.existing.readItem(&splittedLower.stream)
		splitted.create()
		self.upper.read(target.upperPosition)

		cdef i32 n = self.upper.n // 2
		splitted.n = self.upper.n  - n
		self.upper.n = n
		cdef i32 offset = LINKED_PAGE_HEADER_SIZE+n*itemSize
		cdef i32 length = splitted.n*itemSize
		cdef i32 existingLength = offset
		cdef Buffer *stream = &self.upper.stream

		memcpy(splitted.stream.buffer+LINKED_PAGE_HEADER_SIZE, stream.buffer+offset, length)
		bzero(stream.buffer+offset, length)
		cdef LinkedPage targetPage
		cdef i32 index = target.index+1
		if target.index >= n:
			targetPage = splitted
			length += itemSize
			index = index - n
			# print(910, targetPage.n, index)
		else:
			targetPage = self.upper
			existingLength += itemSize
			# print(911, targetPage.n, index)

		cdef i32 targetOffset = LINKED_PAGE_HEADER_SIZE + itemSize*index
		cdef i32 targetLength = itemSize*(targetPage.n - index)
		# print(912, targetOffset, targetLength, index)
		stream = &targetPage.stream
		if targetLength > 0: memcpy(stream.buffer+targetOffset+itemSize, stream.buffer+targetOffset, targetLength)
		
		stream.position = targetOffset
		self.existing.writeUpperItem(stream, splittedLower.position)
		targetPage.n += 1

		if target.subIndex == 0: self.writeLowerHeadToUpper(target, lower, self.upper)

		cdef LinkedPage next
		if self.upper.next > 0:
			if self.upper.next == self.itemStorage.tailPosition: next = self.itemStorage.tail
			else: next = LinkedPage(self.io, self.upper.pageSize, self.upper.itemSize)
			next.readHeader(self.upper.next)
			next.previous = splitted.position
			next.writeHeader()
			# if next.position == self.itemStorage.tailPosition:
			# 	self.itemStorage.tail = next
			# print(999, next)

		splitted.next = self.upper.next
		self.upper.tail = existingLength
		self.upper.next = splitted.position
		self.upper.writeHeaderBuffer()
		self.io.seek(self.upper.position)
		self.upper.stream.position = existingLength
		self.io.write(&self.upper.stream)
		
		splitted.tail = LINKED_PAGE_HEADER_SIZE + length
		splitted.previous = self.upper.position
		splitted.writeHeaderBuffer()
		self.io.seek(splitted.position)
		splitted.stream.position = splitted.tail
		self.io.write(&splitted.stream)

		if isTail: self.itemStorage.tailPosition = splitted.position
		self.itemStorage.lastUpdate = getMicroTime()
		self.itemStorage.writeHeader()

		# cdef i32 i
		# cdef i32 previous, current
		# for i in range(self.upper.n):
		# 	current = (<i32*> (self.upper.stream.buffer+24+i*12+8))[0]
		# 	print(920, i, self.upper.n, current)
		# 	if i > 0 and current < previous: raise ValueError
		# 	previous = current
		# print(921, '%'*50)
		# for i in range(splitted.n):
		# 	current = (<i32*> (splitted.stream.buffer+24+i*12+8))[0]
		# 	print(922, i, splitted.n, current)
		# 	if i > 0 and current < previous: raise ValueError
		# 	previous = current
		# print(923, self.itemStorage.tail, splitted, self.upper)
		
	cdef splitTail(self, DoubleLayerIndex target, Buffer *upper, Buffer *lower):
		cdef i32 itemSize = self.upper.itemSize
		cdef Page splittedLower = self.splitLower(target, lower)
		# NOTE Splitt @target.index -> splitted page must be stored @target.index+1
		cdef i32 index = target.index + 1
		cdef LinkedPage page
		if target.upperPosition == self.itemStorage.tailPosition:
			page = self.itemStorage.tail
			# print(950, page)
		else:
			self.upper.read(target.upperPosition)
			page = self.upper
			# print(951, page)
		
		if target.subIndex == 0: self.writeLowerHeadToUpper(target, lower, page)

		splittedLower.stream.position = PAGE_HEADER_SIZE
		self.existing.readItem(&splittedLower.stream)
		
		cdef i32 offset = LINKED_PAGE_HEADER_SIZE + itemSize*index
		cdef i32 length = itemSize*(self.upper.n - index)
		cdef Buffer *stream = &page.stream
		if length > 0:
			# print(810, offset, length, getIndexString(target))
			memcpy(stream.buffer+offset+itemSize, stream.buffer+offset, length)
		
		stream.position = offset
		self.existing.writeUpperItem(stream, splittedLower.position)
		page.n += 1
		page.tail += itemSize
		self.io.seek(page.position+offset)
		self.io.writeOffset(stream, offset, length+itemSize)
		page.writeHeader()
		self.itemStorage.lastUpdate = getMicroTime()
		self.itemStorage.writeHeader()

		# cdef i32 i
		# print(930, offset, page)
		# cdef i32 previous, current
		# for i in range(page.n):
		# 	current = (<i32*> (stream.buffer+(24+i*itemSize+8)))[0]
		# 	print(931, i, page.n, current)
		# 	if previous > current: raise ValueError
		# 	previous = current

	cdef Page splitLower(self, DoubleLayerIndex target, Buffer *lower):
		cdef i32 itemSize = self.lower.itemSize
		cdef Page splitted = self.splittedLower
		splitted.create()
		self.lower.read(target.lowerPosition)
		cdef i32 n = self.lower.n // 2
		splitted.n = self.lower.n  - n
		self.lower.n = n
		cdef i32 offset = PAGE_HEADER_SIZE+n*itemSize
		cdef i32 length = splitted.n*itemSize
		cdef i32 existingLength = offset
		cdef Buffer *stream = &self.lower.stream
		memcpy(splitted.stream.buffer+PAGE_HEADER_SIZE, stream.buffer+offset, length)
		bzero(stream.buffer+offset, length)
		cdef Page targetPage
		if target.subIndex >= n:
			targetPage = splitted
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
		
		splitted.tail = PAGE_HEADER_SIZE + length
		splitted.writeHeaderBuffer()
		self.io.seek(splitted.position)
		splitted.stream.position = PAGE_HEADER_SIZE + length
		self.io.write(&splitted.stream)
		return splitted

	cdef DoubleLayerIndex searchInsertPosition(self, HashPageNode entry, HashPageNode found):
		cdef DoubleLayerIndex target
		if self.itemStorage.rootPosition != found.pagePosition:
			self.itemStorage.readHeader(found.pagePosition)
		self.upper.read(self.itemStorage.headPosition)
		self.upperSearch.setPage(self.upper)
		self.upperSearch.readPosition(self.itemStorage.lastUpdate)
		self.upperPageStream.position = 0
		entry.writeUpperItem(&self.upperPageStream, -1)
		self.upperPageStream.position = 0
		target.index = self.upperSearch.getGreaterEqualPage(&self.upperPageStream)
		# print(670, target.index)
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
