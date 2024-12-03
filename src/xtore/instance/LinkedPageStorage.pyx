from xtore.BaseType cimport i32, i64, f64
from xtore.common.Buffer cimport Buffer, setBuffer, getBuffer, initBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.TimeUtil cimport getMicroTime
from xtore.instance.LinkedPage cimport LinkedPage

from libc.stdlib cimport free, malloc
from libc.string cimport memcmp


cdef char *MAGIC = "@XT_PAGE"
cdef i32 MAGIC_LENGTH = 8
cdef i32 HEADER_SIZE = 32 + MAGIC_LENGTH

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
	
	def __repr__(self) -> str:
		return f'<LinkedPageStorage {self.rootPosition} t={self.tailPosition} ps={self.pageSize} is={self.itemSize}>'

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		self.tailPosition = self.rootPosition + HEADER_SIZE
		self.writeHeader()
		self.tail.position = -1
		self.createPage()
		self.headPosition = self.tail.position
		self.writeHeader()
		return self.rootPosition

	cdef writeHeader(self):
		self.headerStream.position = 0
		setBuffer(&self.headerStream, MAGIC, MAGIC_LENGTH)
		setBuffer(&self.headerStream, <char *> &self.tailPosition, 8)
		setBuffer(&self.headerStream, <char *> &self.headPosition, 8)
		setBuffer(&self.headerStream, <char *> &self.lastUpdate, 8)
		setBuffer(&self.headerStream, <char *> &self.pageSize, 4)
		setBuffer(&self.headerStream, <char *> &self.itemSize, 4)
		self.io.seek(self.rootPosition)
		self.io.write(&self.headerStream)

	cdef readHeader(self, i64 rootPosition):
		self.rootPosition = rootPosition
		self.io.seek(self.rootPosition)
		self.io.read(&self.headerStream, HEADER_SIZE)
		cdef bint isMagic = memcmp(MAGIC, self.headerStream.buffer, MAGIC_LENGTH)
		self.headerStream.position += MAGIC_LENGTH
		if isMagic != 0:
			raise ValueError('Wrong Magic for LinkedPageStorage')
		self.tailPosition = (<i64 *> getBuffer(&self.headerStream, 8))[0]
		self.headPosition = (<i64 *> getBuffer(&self.headerStream, 8))[0]
		self.lastUpdate = (<f64 *> getBuffer(&self.headerStream, 8))[0]
		self.pageSize = (<i32 *> getBuffer(&self.headerStream, 4))[0]
		self.itemSize = (<i32 *> getBuffer(&self.headerStream, 4))[0]
		self.tail.read(self.tailPosition)

	cdef appendBuffer(self, Buffer *stream):
		cdef bint isSuccess
		if self.itemSize > 0:
			isSuccess = self.tail.appendBuffer(stream)
			if not isSuccess:
				self.createPage()
				self.tail.appendBuffer(stream)
			self.lastUpdate = getMicroTime()
			self.writeHeader()
		else:
			print("*** WARNING LinkedPageStorage is FIXED SIZE. It is not possible to append buffer.")

	cdef appendValue(self, char *value):
		cdef bint isSuccess
		if self.itemSize > 0:
			isSuccess = self.tail.appendValue(value)
			if not isSuccess:
				self.createPage()
				self.tail.appendValue(value)
			self.lastUpdate = getMicroTime()
			self.writeHeader()
		else:
			print(f"*** WARNING LinkedPageStorage is VARY SIZE. It is not possible to append value {self.itemSize}.")
	
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

