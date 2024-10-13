from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage, LINKED_PAGE_HEADER_SIZE
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64
from libc.string cimport memcpy

cdef class LinkedPageIterator:
	def __init__(self, LinkedPageStorage storage):
		self.storage = storage
		self.current = LinkedPage(storage.io, storage.pageSize, storage.itemSize)
		self.currentPosition = -1
	
	cdef start(self):
		self.current.read(self.storage.headPosition)
		self.currentPosition = LINKED_PAGE_HEADER_SIZE

	cdef bint getNextBuffer(self, Buffer *stream):
		if self.currentPosition >= self.current.tail:
			if self.current.next < 0: return False
			self.current.read(self.current.next)
			self.currentPosition = LINKED_PAGE_HEADER_SIZE
		
		cdef i64 position = self.current.position + self.currentPosition
		self.storage.io.seek(position)
		self.storage.io.read(&self.current.stream, 4)
		cdef i32 size = (<i32 *> self.current.stream.buffer)[0]
		self.storage.io.seek(position+4)
		self.storage.io.read(stream, size)
		self.currentPosition += (4+size)
		return True

	cdef bint getNextValue(self, char *buffer):
		if self.currentPosition >= self.current.tail:
			if self.current.next < 0: return False
			self.current.read(self.current.next)
			self.currentPosition = LINKED_PAGE_HEADER_SIZE
		cdef i64 position = self.current.position + self.currentPosition
		self.storage.io.seek(position)
		self.storage.io.read(&self.current.stream, self.storage.itemSize)
		memcpy(buffer, self.current.stream.buffer, self.storage.itemSize)
		self.currentPosition += self.storage.itemSize
		return True