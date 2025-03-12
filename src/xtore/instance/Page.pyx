from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer, setBuffer, getBuffer, initBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from libc.string cimport memcpy
from libc.stdlib cimport malloc
from posix.strings cimport bzero

cdef i32 PAGE_HEADER_SIZE = 8

cdef class Page:
	def __init__(self, StreamIOHandler io, i32 pageSize, i32 itemSize):
		self.headerSize = PAGE_HEADER_SIZE
		self.io = io
		self.pageSize = pageSize
		self.itemSize = itemSize
		self.position = 0
		self.tail = self.headerSize
		self.n = 0
		initBuffer(&self.stream, <char *> malloc(pageSize), pageSize)
	
	def __dealloc__(self):
		releaseBuffer(&self.stream)
	
	def __repr__(self) -> str:
		return f'<Page {self.position} ps={self.pageSize} is={self.itemSize} t={self.tail} n={self.n}>'
	
	cdef reset(self):
		bzero(self.stream.buffer, self.pageSize)
		self.tail = self.headerSize
		self.n = 0
	
	cdef i64 create(self):
		self.position = self.io.getTail()
		# print(800, f"Page.create io@{id(self.io)} position={self.position}")
		self.reset()
		self.writeHeader()
		self.stream.position = self.pageSize
		self.io.fill(&self.stream)
		# print(801, f"Page.create after create tail={self.io.getTail()}")
		self.stream.position = self.headerSize
		return self.position
	
	cdef copyHeader(self, Page other):
		self.position = other.position
		self.tail = other.tail
		self.n = other.n

	cdef i32 getCapacity(self):
		return self.pageSize - self.tail
	
	cdef bint appendBuffer(self, Buffer *stream):
		if self.itemSize >= 0: return False
		cdef i32 capacity = self.pageSize-self.tail
		cdef i32 size
		if capacity >= stream.position:
			size = stream.position + 4
			setBuffer(&self.stream, <char *> &stream.position, 4)
			setBuffer(&self.stream, stream.buffer, stream.position)
			self.io.seek(self.position+self.tail)
			self.io.writeOffset(&self.stream, self.tail, size)
			self.tail += size
			self.n += 1
			self.writeHeader()
			return True
		else:
			return False

	cdef bint appendValue(self, char *value):
		if self.itemSize <= 0: return False
		cdef i32 capacity = self.pageSize-self.tail
		if capacity >= self.itemSize:
			memcpy(self.stream.buffer+self.tail, value, self.itemSize)
			self.io.seek(self.position+self.tail)
			self.io.writeOffset(&self.stream, self.tail, self.itemSize)
			self.tail += self.itemSize
			self.n += 1
			self.writeHeader()
			return True
		else:
			return False

	cdef bint writeValue(self, char *value, i32 index):
		if self.itemSize <= 0: return False
		cdef i32 position = self.headerSize + self.itemSize*index
		if position <= self.pageSize:
			memcpy(self.stream.buffer+position, value, self.itemSize)
			self.io.seek(self.position+position)
			self.io.writeOffset(&self.stream, position, self.itemSize)
			self.writeHeader()
			return True
		else:
			return False

	cdef read(self, i64 position):
		self.position = position
		self.io.seek(self.position)
		self.io.read(&self.stream, self.pageSize)
		self.readHeaderBuffer()
		self.hasBody = True
	
	cdef readHeader(self, i64 position):
		self.position = position
		self.io.seek(self.position)
		self.io.read(&self.stream, PAGE_HEADER_SIZE)
		self.readHeaderBuffer()
		self.hasBody = False
		
	cdef readHeaderBuffer(self):
		self.stream.position = 0
		self.tail = (<i32 *> getBuffer(&self.stream, 4))[0]
		self.n = (<i32 *> getBuffer(&self.stream, 4))[0]

	cdef write(self):
		self.writeHeaderBuffer()
		self.stream.position = self.tail
		self.io.seek(self.position)
		self.io.write(&self.stream)
	
	cdef writeHeader(self):
		self.writeHeaderBuffer()
		self.io.seek(self.position)
		self.io.write(&self.stream)
		self.stream.position = self.tail
		# if self.position == 7827669:
		# 	print(803, self)
		# 	self.readHeader(self.position)
		# 	print(804, self)
	
	cdef writeHeaderBuffer(self):
		self.stream.position = 0
		setBuffer(&self.stream, <char *> &self.tail, 4)
		setBuffer(&self.stream, <char *> &self.n, 4)

	cdef startIteration(self):
		self.stream.position = self.headerSize

	cdef bint hasNext(self):
		cdef i32 size = (<i32 *> getBuffer(&self.stream, 4))[0]
		if size == 0: return False
		return size+self.stream.position < self.pageSize
	
	cdef i32 getNext(self):
		cdef i32 size = (<i32 *> getBuffer(&self.stream, 4))[0]
		if size > 0: self.stream.position += size+4
		return size

