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
		self.storage.io.seek(self.storage.rootPosition)
		self.storage.io.read(&self.streamList[0], self.pageBufferSize)
		self.hasNext = self.moveNext(&self.streamList[0], 0, 0)

	cdef bint getNext(self, RecordNode node):
		if not self.hasNext: return self.hasNext
		self.storage.readNodeKey(self.currentPosition, node)
		self.storage.readNodeValue(node)
		cdef bint hasNext = self.moveNext(self.currentStream, self.currentDepth, self.currentIndex+1)
		if hasNext: return True
		for i in range(self.currentDepth-1, -1, -1):
			hasNext = self.moveNext(&self.streamList[i], i, self.index[i]+1)
			if hasNext: break
		self.hasNext = hasNext
		return True
	
	cdef bint moveNext(self, Buffer *stream, i32 depth, i32 start):
		if depth >= self.depth: return False
		cdef i32 position
		cdef u64 meta
		cdef u64 child
		cdef u8 state
		cdef bint isFound
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
				stream = &self.streamList[depth+1]
				self.storage.io.seek(child)
				self.storage.io.read(stream, self.pageBufferSize)
				isFound = self.moveNext(stream, depth+1, 0)
				self.index[depth] = i
				if isFound: return True
				continue
		return False
