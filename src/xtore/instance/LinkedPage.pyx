from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer, setBuffer, getBuffer, initBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.Page cimport Page
from libc.stdlib cimport malloc
from posix.strings cimport bzero

cdef i32 LINKED_PAGE_HEADER_SIZE = 24

cdef class LinkedPage (Page):
	def __init__(self, StreamIOHandler io, i32 pageSize, i32 itemSize):
		self.headerSize = LINKED_PAGE_HEADER_SIZE
		self.io = io
		self.pageSize = pageSize
		self.itemSize = itemSize
		self.position = 0
		self.tail = self.headerSize
		self.next = -1
		self.previous = -1
		self.n = 0
		initBuffer(&self.stream, <char *> malloc(pageSize), pageSize)
	
	def __dealloc__(self):
		releaseBuffer(&self.stream)
	
	def __repr__(self) -> str:
		return f'<LinkedPage {self.position} n={self.next} p={self.previous} ps={self.pageSize} is={self.itemSize} t={self.tail} n={self.n}>'

	cdef copyHeader(self, Page otherPage):
		cdef LinkedPage other = <LinkedPage> otherPage
		self.position = other.position
		self.next = other.next
		self.previous = other.previous
		self.tail = other.tail
		self.n = other.n

	cdef reset(self):
		bzero(self.stream.buffer, self.pageSize)
		self.tail = self.headerSize
		self.next = -1
		self.previous = -1
		self.n = 0

	cdef read(self, i64 position):
		self.position = position
		self.io.seek(self.position)
		self.io.read(&self.stream, self.pageSize)
		self.readHeaderBuffer()
		self.hasBody = True
	
	cdef readHeader(self, i64 position):
		self.position = position
		self.io.seek(self.position)
		self.io.read(&self.stream, LINKED_PAGE_HEADER_SIZE)
		self.readHeaderBuffer()
		self.hasBody = False
		
	cdef readHeaderBuffer(self):
		self.stream.position = 0
		self.next = (<i64 *> getBuffer(&self.stream, 8))[0]
		self.previous = (<i64 *> getBuffer(&self.stream, 8))[0]
		self.tail = (<i32 *> getBuffer(&self.stream, 4))[0]
		self.n = (<i32 *> getBuffer(&self.stream, 4))[0]
	
	cdef writeHeaderBuffer(self):
		self.stream.position = 0
		setBuffer(&self.stream, <char *> &self.next, 8)
		setBuffer(&self.stream, <char *> &self.previous, 8)
		setBuffer(&self.stream, <char *> &self.tail, 4)
		setBuffer(&self.stream, <char *> &self.n, 4)

	cdef startIteration(self):
		self.stream.position = self.headerSize

