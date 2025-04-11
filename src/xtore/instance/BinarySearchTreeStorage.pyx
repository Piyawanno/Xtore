from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, setBuffer, setBoolean, getBuffer, getBoolean, initBuffer, releaseBuffer

from libc.stdlib cimport malloc
from libc.string cimport memcmp

cdef char *MAGIC = "@XT_BSTR"
cdef i32 MAGIC_LENGTH = 0

cdef i32 BST_STORAGE_HEADER_SIZE = 16
cdef i32 BST_NODE_OFFSET = 24

cdef i32 BUFFER_SIZE = 1 << 13

cdef class BinarySearchTreeStorage (BasicStorage):
	def __init__(self, StreamIOHandler io, CollisionMode mode):
		self.io = io
		self.mode = mode
		self.headerSize = BST_STORAGE_HEADER_SIZE
		initBuffer(&self.headerStream, <char *> malloc(BST_STORAGE_HEADER_SIZE), BST_STORAGE_HEADER_SIZE)
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.comparingNode = self.createNode()

	def __dealloc__(self):
		releaseBuffer(&self.headerStream)
		releaseBuffer(&self.stream)

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		self.rootNodePosition = -1
		self.writeHeader()
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
		setBuffer(stream, <char *> &self.rootNodePosition, 8)

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
		self.rootNodePosition = (<i64*> getBuffer(&self.headerStream, 8))[0]

	cdef RecordNode get(self, RecordNode reference, RecordNode result):
		if self.rootNodePosition < 0: return None
		cdef i64 position = self.rootNodePosition
		cdef i64 nodePosition
		cdef i64 left
		cdef i64 right
		cdef i32 compareResult
		cdef RecordNode stored

		while True:
			self.io.seek(position)
			self.io.read(&self.stream, BST_NODE_OFFSET)
			nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
			left = (<i64*> getBuffer(&self.stream, 8))[0]
			right = (<i64*> getBuffer(&self.stream, 8))[0]
			stored = self.readNodeKey(nodePosition, result)
			compareResult = reference.compare(stored)
			if compareResult == 0:
				self.readNodeValue(stored)
				return stored
			elif compareResult > 0:
				if right > 0: position = right
				else: 
					return None
			else:
				if left > 0: position = left
				else: 
					return None

	cdef set(self, RecordNode reference):
		cdef i64 placeHolder = -1
		if self.rootNodePosition < 0:
			self.appendNode(reference)
			self.stream.position = 0
			setBuffer(&self.stream, <char *> &reference.position, 8)
			setBuffer(&self.stream, <char *> &placeHolder, 8)
			setBuffer(&self.stream, <char *> &placeHolder, 8)
			self.rootNodePosition = self.io.getTail()
			self.io.append(&self.stream)
			return
		
		cdef i64 position = self.rootNodePosition
		cdef i64 nodePosition
		cdef i64 left
		cdef i64 right
		cdef i32 compareResult
		cdef RecordNode stored
		while True:
			self.io.seek(position)
			self.io.read(&self.stream, BST_NODE_OFFSET)
			nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
			left = (<i64*> getBuffer(&self.stream, 8))[0]
			right = (<i64*> getBuffer(&self.stream, 8))[0]
			stored = self.readNodeKey(nodePosition, self.comparingNode)
			compareResult = reference.compare(stored)
			if compareResult == 0:
				reference.position = nodePosition
				self.writeNode(reference)
				break
			elif compareResult > 0:
				if right > 0:
					position = right
				else:
					self.appendNode(reference)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &reference.position, 8)
					setBuffer(&self.stream, <char *> &placeHolder, 8)
					setBuffer(&self.stream, <char *> &placeHolder, 8)
					right = self.io.getTail()
					self.io.append(&self.stream)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &right, 8)
					self.io.seek(position+16)
					self.io.write(&self.stream)
					break
			else:
				if left > 0:
					position = left
				else:
					self.appendNode(reference)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &reference.position, 8)
					setBuffer(&self.stream, <char *> &placeHolder, 8)
					setBuffer(&self.stream, <char *> &placeHolder, 8)
					left = self.io.getTail()
					self.io.append(&self.stream)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &left, 8)
					self.io.seek(position+8)
					self.io.write(&self.stream)
					break
	