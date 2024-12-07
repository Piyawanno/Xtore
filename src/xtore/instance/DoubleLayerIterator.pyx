from xtore.BaseType cimport i32, i64
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.RecordPageNode cimport RecordPageNode
from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage

from libc.stdlib cimport malloc, free

cdef class DoubleLayerIterator:
	def __init__(self, LinkedPageStorage storage, i32 lowerPageSize, i32 lowerItemSize):
		self.storage = storage
		self.upper = LinkedPage(storage.io, storage.pageSize, storage.itemSize)
		self.lower = Page(storage.io, lowerPageSize, lowerItemSize)

		cdef i32 positionSize = <i32> ((self.upper.pageSize-self.upper.headerSize)/self.upper.itemSize)
		self.upperPosition = <i32 *> malloc(positionSize*4)
		cdef int i
		cdef int j = self.upper.headerSize
		for i in range(positionSize):
			self.upperPosition[i] = j
			j += self.upper.itemSize
		
		positionSize = <i32> ((self.lower.pageSize-self.lower.headerSize)/self.lower.itemSize)
		self.lowerPosition = <i32 *> malloc(positionSize*4)
		j = self.lower.headerSize
		for i in range(positionSize):
			self.lowerPosition[i] = j
			j += self.lower.itemSize
	
	def __dealloc__(self):
		if self.upperPosition != NULL:
			free(self.upperPosition)
			self.upperPosition = NULL
		if self.lowerPosition != NULL:
			free(self.lowerPosition)
			self.lowerPosition = NULL


	cdef start(self, i64 headPosition):
		self.currentIndex = 0
		self.currentSubIndex = 0
		self.upper.read(headPosition)
		cdef i64 lowerPosition = self.getLowerPosition(0)
		self.lower.read(lowerPosition)

	cdef bint getNext(self, RecordPageNode entry):
		cdef DoubleLayerIndex index
		cdef bint result = self.move(&index)
		# print(400, result, getIndexString(index), self.upper.next, self.currentIndex, self.currentSubIndex, self.upper.n, self.lower.n)
		if not result: return False
		self.entryStream.buffer = (self.lower.stream.buffer+index.offset)
		self.entryStream.position = 0
		entry.readItem(&self.entryStream)
		return True
	
	cdef bint move(self, DoubleLayerIndex *index):
		cdef i64 lowerPosition
		cdef i32 positionSize = <i32> ((self.lower.pageSize-self.lower.headerSize)/self.lower.itemSize)
		index.upperPosition = self.upper.position
		index.lowerPosition = self.lower.position
		if self.currentSubIndex < self.lower.n:
			index[0].offset = self.lowerPosition[self.currentSubIndex]
			index[0].index = self.currentIndex
			index[0].subIndex = self.currentSubIndex
			self.currentSubIndex += 1
		else:
			# print(401, '-'*50, self.upper.next < 0, self.currentIndex+1 >= self.upper.n)
			if self.upper.next < 0 and self.currentIndex+1 >= self.upper.n:
				return False
			elif self.currentIndex <= self.upper.n:
				self.currentIndex += 1
				index.lowerPosition = self.getLowerPosition(self.currentIndex)
				self.lower.read(index.lowerPosition)
				index[0].index = self.currentIndex
			else:
				if self.upper.next < 0: return False
				# print(401, '#'*50)
				self.upper.read(self.upper.next)
				index.upperPosition = self.upper.position
				index.lowerPosition = self.getLowerPosition(0)
				self.lower.read(index.lowerPosition)
				index[0].index = 0
				self.currentIndex = 0
			index[0].subIndex = 0
			index[0].offset = self.lowerPosition[0]
			self.currentSubIndex = 1
		return True

	cdef i64 getLowerPosition(self, i32 index):
		cdef i32 offset = self.upperPosition[index]
		return (<i64 *> (self.upper.stream.buffer+offset))[0]
	
	cdef setPosition(self, DoubleLayerIndex index):
		self.upper.read(index.upperPosition)
		self.lower.read(index.lowerPosition)
		self.currentIndex = index.index
		self.currentSubIndex = index.subIndex
