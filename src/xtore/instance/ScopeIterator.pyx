from xtore.BaseType cimport u8, i32, u64
from xtore.common.Buffer cimport Buffer, initBuffer
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage, OccupationState
from xtore.instance.RecordNode cimport RecordNode

from libc.stdlib cimport malloc, free

cdef class ScopeIterator (BasicIterator):
	def __init__(self, ScopeTreeStorage storage):
		self.storage = storage
		self.depth = storage.getDepth()
		self.pagePosition = <u64 *> malloc(self.depth*8)
		self.index = <i32 *> malloc(self.depth*4)
		self.pageBufferSize = storage.pageSize*8
		cdef i32 bufferSize = self.pageBufferSize*self.depth
		self.buffer = <char *> malloc(bufferSize)
		self.streamList = <Buffer *> malloc(sizeof(Buffer)*self.depth)
		cdef i32 position = 0
		for i in range(self.depth):
			initBuffer(&self.streamList[i], self.buffer+position, self.pageBufferSize)
			position += self.pageBufferSize

	def __dealloc__(self):
		free(self.pagePosition)
		free(self.index)
		free(self.buffer)
		free(self.streamList)

	cdef start(self):
		self.getHead()

	cdef bint getNext(self, RecordNode node):
		if not self.hasNext: return self.hasNext
		self.storage.readNodeKey(self.currentPosition, node)
		self.storage.readNodeValue(node)
		self.hasNext = self.moveNextPage()
		return True
	
	cdef bint moveNextPage(self):
		cdef bint hasNext = self.moveNext(self.currentStream, self.currentDepth, self.currentIndex+1)
		if hasNext: return True
		for i in range(self.currentDepth-1, -1, -1):
			self.currentPage = self.pagePosition[i]
			hasNext = self.moveNext(&self.streamList[i], i, self.index[i]+1)
			if hasNext: break
		return hasNext

	cdef bint moveBackPage(self):
		cdef bint hasNext = self.moveBack(self.currentStream, self.currentDepth, self.currentIndex-1)
		if hasNext: return True
		for i in range(self.currentDepth-1, -1, -1):
			self.currentPage = self.pagePosition[i]
			hasNext = self.moveBack(&self.streamList[i], i, self.index[i]-1)
			if hasNext: break
		return hasNext
	
	cdef bint moveNext(self, Buffer *stream, i32 depth, i32 start):
		if depth >= self.depth: return False
		cdef i32 position
		cdef u64 meta
		cdef u64 child
		cdef u8 state
		cdef bint isFound
		cdef Buffer *childStream

		for i in range(start, self.storage.pageSize):
			position = i << 3
			meta = (<u64 *> (stream.buffer+position))[0]
			state = meta &  3
			child = meta >> 2
			if state == OccupationState.NODE:
				self.currentIndex = i
				self.currentPosition = child
				self.currentDepth = depth
				self.currentStream = stream
				return True
			elif state == OccupationState.PAGE:
				if depth >= self.depth-1: return False
				childStream = &self.streamList[depth+1]
				self.storage.io.seek(child)
				self.storage.io.read(childStream, self.pageBufferSize)
				self.currentPage = child
				isFound = self.moveNext(childStream, depth+1, 0)
				self.index[depth] = i
				self.pagePosition[depth+1] = child
				if isFound: return True
		return False

	cdef bint moveBack(self, Buffer *stream, i32 depth, i32 start):
		if depth >= self.depth: return False
		cdef i32 position
		cdef u64 meta
		cdef u64 child
		cdef u8 state
		cdef bint isFound
		cdef Buffer *childStream
		for i in range(start, -1, -1):
			position = i << 3
			meta = (<u64 *> (stream.buffer+position))[0]
			state = meta &  3
			child = meta >> 2
			if state == OccupationState.NODE:
				self.currentIndex = i
				self.currentPosition = child
				self.currentDepth = depth
				self.currentStream = stream
				return True
			elif state == OccupationState.PAGE:
				if depth >= self.depth-1: return False
				childStream = &self.streamList[depth+1]
				self.storage.io.seek(child)
				self.storage.io.read(childStream, self.pageBufferSize)
				self.currentPage = child
				isFound = self.moveBack(childStream, depth+1, self.storage.pageSize-1)
				self.index[depth] = i
				self.pagePosition[depth] = child
				if isFound: return True
				continue
		return False

	cdef getHead(self):
		self.storage.io.seek(self.storage.rootPagePosition)
		self.storage.io.read(&self.streamList[0], self.pageBufferSize)
		self.pagePosition[0] = self.storage.rootPagePosition
		self.hasNext = self.moveNext(&self.streamList[0], 0, 0)

	cdef getTail(self):
		self.storage.io.seek(self.storage.rootPagePosition)
		self.storage.io.read(&self.streamList[0], self.pageBufferSize)
		self.pagePosition[0] = self.storage.rootPagePosition
		self.hasNext = self.moveBack(&self.streamList[0], 0, self.storage.pageSize-1)