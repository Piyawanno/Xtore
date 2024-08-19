from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer, setBuffer, getBuffer, initBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.LinkedPage cimport LinkedPage
from libc.stdlib cimport free, malloc

cdef i32 HEADER_SIZE = 16

cdef class LinkedPageStorage:
	def __init__(self, StreamIOHandler io, i32 pageSize, i32 itemSize):
		self.io = io
		self.pageSize = pageSize
		self.itemSize = itemSize
		self.rootPosition = -1
		self.tailPosition = -1
		self.tail = LinkedPage(io, pageSize, itemSize)
		initBuffer(&self.headerStream, <char *> malloc(HEADER_SIZE), HEADER_SIZE)
	
	def __dealloc__(self):
		releaseBuffer(&self.headerStream)

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		self.tailPosition = self.rootPosition + HEADER_SIZE
		self.writeHeader()
		self.tail.position = -1
		self.createPage()
		return self.rootPosition

	cdef writeHeader(self):
		self.headerStream.position = 0
		setBuffer(&self.headerStream, <char *> &self.tailPosition, 8)
		setBuffer(&self.headerStream, <char *> &self.pageSize, 4)
		setBuffer(&self.headerStream, <char *> &self.itemSize, 4)
		self.io.seek(self.rootPosition)
		self.io.write(&self.headerStream)

	cdef readHeader(self, i64 rootPosition):
		self.rootPosition = rootPosition
		self.io.seek(self.rootPosition)
		self.io.read(&self.headerStream, HEADER_SIZE)
		self.tailPosition = (<i64 *> getBuffer(&self.headerStream, 8))[0]
		self.pageSize = (<i32 *> getBuffer(&self.headerStream, 4))[0]
		self.itemSize = (<i32 *> getBuffer(&self.headerStream, 4))[0]
		self.tail.read(self.tailPosition)

	cdef appendBuffer(self, Buffer *stream):
		cdef bint isSuccess
		if self.itemSize < 0:
			isSuccess = self.tail.appendBuffer(stream)
			if not isSuccess:
				self.createPage()
				self.tail.appendBuffer(stream)
		else:
			print("*** WARNING LinkedPageStorage is FIXED SIZE. It is not possible to append buffer.")

	cdef appendValue(self, char *value):
		cdef bint isSuccess
		if self.itemSize < 0:
			isSuccess = self.tail.appendValue(value)
			if not isSuccess:
				self.createPage()
				self.tail.appendValue(value)
		else:
			print("*** WARNING LinkedPageStorage is VARY SIZE. It is not possible to append value.")
	
	cdef createPage(self):
		cdef i64 previous = self.tail.position
		cdef i64 next = self.io.getTail()
		if previous > 0:
			self.tail.next = next
			self.tail.writeHeader()

		self.tail.reset()
		self.tail.position = next
		self.tail.previous = previous
		self.tail.writeHeaderBuffer()
		self.tail.stream.position = self.pageSize
		self.io.fill(&self.tail.stream)
		self.tail.stream.position = self.tail.tail
		self.tailPosition = next
		self.writeHeader()

