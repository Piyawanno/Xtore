from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, setBuffer, setBoolean, getBuffer, getBoolean, initBuffer, releaseBuffer

from libc.stdlib cimport malloc
from libc.string cimport memcmp

cdef char *MAGIC = "@XT_BSTR"
cdef i32 MAGIC_LENGTH = 0

cdef i32 BST_STORAGE_HEADER_SIZE = 8

cdef class RangeTreeStorage:
	def __init__(self, StreamIOHandler io, CollisionMode mode):
		self.mode = mode
		self.headerSize = BST_STORAGE_HEADER_SIZE
		initBuffer(&self.headerStream, <char *> malloc(BST_STORAGE_HEADER_SIZE), BST_STORAGE_HEADER_SIZE)

	def __dealloc__(self):
		releaseBuffer(&self.headerStream)

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		return self.rootPosition

	cdef RecordNode createNode(self):
		raise NotImplementedError

	cdef writeHeader(self):
		self.headerStream.position = 0
		self.writeHeaderBuffer(&self.headerStream)
		self.io.seek(self.rootPosition)
		self.io.write(&self.headerStream)
		self.isCreated = True

	cdef writeHeaderBuffer(self, Buffer *stream):
		setBuffer(stream, MAGIC, MAGIC_LENGTH)

	cdef readHeader(self, i64 rootPosition):
		self.rootPosition = rootPosition
		self.io.seek(self.rootPosition)
		self.io.read(&self.headerStream, self.headerSize)
		self.readHeaderBuffer(&self.headerStream)

	cdef readHeaderBuffer(self, Buffer *stream):
		cdef bint isMagic = memcmp(MAGIC, self.headerStream.buffer, MAGIC_LENGTH)
		self.headerStream.position += MAGIC_LENGTH
		if isMagic != 0:
			raise ValueError('Wrong Magic for BinarySearchTreeStorage')

	cdef setHeaderSize(self, i32 headerSize):
		self.headerSize = headerSize

	cdef setName(self, str name):
		self.name = name