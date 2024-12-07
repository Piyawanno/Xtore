from xtore.BaseType cimport i32, i64
from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.instance.RecordPageNode cimport RecordPageNode

from libc.stdlib cimport malloc, free

cdef class DoubleLayerRangeResult:
	def __init__(self, LinkedPage upper, Page lower):
		self.upper = upper
		self.lower = lower
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

	def __repr__(self) -> str:
		return f'<DoubleLayerRangeResult {self.startPosition} [{self.startIndex}-{self.endIndex}] {self.endPosition} [{self.startSubIndex}-{self.endSubIndex}]>'

	cdef start(self):
		self.currentPosition = self.startPosition
		self.currentIndex = self.startIndex
		self.currentSubIndex = self.startSubIndex

		self.upper.read(self.startPosition)
		cdef i64 lowerPosition = self.getLowerPosition(self.startIndex)
		self.lower.read(lowerPosition)

	cdef bint getNext(self, RecordPageNode entry):
		cdef i32 offset
		cdef i64 lowerPosition
		cdef bint result = self.currentPosition >= self.endPosition
		result = result & (self.currentIndex >= self.endIndex)
		result = result & (self.currentSubIndex >= self.endSubIndex)
		if result:
			return False
		if self.currentSubIndex < self.lower.n:
			offset = self.lowerPosition[self.currentSubIndex]
			self.currentSubIndex += 1
		else:
			if self.currentIndex < self.upper.n:
				self.currentIndex += 1
				lowerPosition = self.getLowerPosition(self.currentIndex)
				self.lower.read(lowerPosition)
			else:
				if self.upper.next < 0:
					return False
				self.currentPosition = self.upper.next
				self.upper.read(self.upper.next)
				lowerPosition = self.getLowerPosition(self.currentIndex)
				self.lower.read(lowerPosition)
				self.currentIndex = 1
			offset = self.lowerPosition[0]
			self.currentSubIndex = 1
		
		self.entryStream.buffer = (self.lower.stream.buffer+offset)
		self.entryStream.position = 0
		entry.readItem(&self.entryStream)
		return True
	
	cdef i64 getLowerPosition(self, i32 index):
		cdef i32 offset = self.upperPosition[index]
		return (<i64 *> (self.upper.stream.buffer+offset))[0]
	