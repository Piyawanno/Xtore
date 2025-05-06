from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer, setBuffer, getBuffer, initBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.test.DataSet cimport DataSet
from libc.stdlib cimport malloc
from libc.string cimport memcmp
from xtore.test.DataSet cimport DataSet

cdef char *MAGIC = "@XT_BSTR"
cdef i32 MAGIC_LENGTH = 0

cdef i32 BST_STORAGE_HEADER_SIZE = 16
cdef i32 BST_NODE_OFFSET = 24

cdef i32 BUFFER_SIZE = 1 << 13

cdef class HomomorphicBSTStorage (BasicStorage):
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

			if compareResult == 1:
				if left > 0:
					position = left
				else:
					return stored
			else:
				if right > 0:
					position = right
				else:
					return stored
			
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

			if compareResult == 1:
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
					self.io.seek(position + 8)
					self.io.write(&self.stream)
					break
			else:
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
					self.io.seek(position + 16)
					self.io.write(&self.stream)
					break

	cdef list getGreater(self, RecordNode dataSet, int threshold):
		if self.rootNodePosition < 0: return None
		cdef list resultList = []
		self.inOrderGreaterSearch(self.rootNodePosition, dataSet, threshold, resultList)
		return resultList
	
	cdef list getLess(self, RecordNode dataSet, int threshold):
		if self.rootNodePosition < 0: return None
		cdef list resultList = []
		self.inOrderLessSearch(self.rootNodePosition, dataSet, threshold, resultList)
		return resultList

	cdef void inOrderGreaterSearch(self, i64 position, RecordNode dataSet, int threshold, list resultList):
		if position < 0:
			return

		cdef i64 nodePosition, left, right
		cdef DataSet currentNode
		cdef int cmp

		self.io.seek(position)
		self.io.read(&self.stream, BST_NODE_OFFSET)
		nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
		left = (<i64*> getBuffer(&self.stream, 8))[0]
		right = (<i64*> getBuffer(&self.stream, 8))[0]
		currentNode = self.readNodeKey(nodePosition, None)

		cmp = currentNode.compareIntToRecord(dataSet, threshold)
		
		if cmp == 1:
			self.inOrderGreaterSearch(left, dataSet, threshold, resultList)
			resultList.append(currentNode)
			self.collectSubTree(right, resultList)

		else:
			self.inOrderGreaterSearch(right, dataSet, threshold, resultList)

	cdef void inOrderLessSearch(self, i64 position, RecordNode dataSet, int threshold, list resultList):
		if position < 0:
			return

		cdef i64 nodePosition, left, right
		cdef DataSet currentNode
		cdef int cmp

		self.io.seek(position)
		self.io.read(&self.stream, BST_NODE_OFFSET)
		nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
		left = (<i64*> getBuffer(&self.stream, 8))[0]
		right = (<i64*> getBuffer(&self.stream, 8))[0]
		currentNode = self.readNodeKey(nodePosition, None)

		cmp = currentNode.compareIntToRecord(dataSet, threshold)
		
		if cmp == 0:
			self.collectSubTree(left, resultList)
			resultList.append(currentNode)
			self.inOrderLessSearch(right, dataSet, threshold, resultList)
		else:
			self.inOrderLessSearch(left, dataSet, threshold, resultList)

	cdef void collectSubTree(self, i64 position, list resultList):
		cdef i64 nodePosition, left, right
		cdef RecordNode currentNode

		while position >= 0:
			self.io.seek(position)
			self.io.read(&self.stream, BST_NODE_OFFSET)
			nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
			left = (<i64*> getBuffer(&self.stream, 8))[0]
			right = (<i64*> getBuffer(&self.stream, 8))[0]
			currentNode = self.readNodeKey(nodePosition, None)

			self.collectSubTree(left, resultList)
			resultList.append(currentNode)
			position = right

	cdef list getRangeData(self, RecordNode dataSet, int low, int high):
			if self.rootNodePosition < 0: return None
			cdef list resultList = []
			cdef i64 position = self.rootNodePosition
			cdef i64 nodePosition, left, right
			cdef DataSet currentNode

			while position >= 0:
				self.io.seek(position)
				self.io.read(&self.stream, BST_NODE_OFFSET)
				nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
				left = (<i64*> getBuffer(&self.stream, 8))[0]
				right = (<i64*> getBuffer(&self.stream, 8))[0]
				currentNode = self.readNodeKey(nodePosition, None)

				cmpLow = currentNode.compareIntToRecord(dataSet, low)
				cmpHigh = currentNode.compareIntToRecord(dataSet, high)

				if cmpLow == 1 and cmpHigh == 0:
					break
				elif cmpHigh == 0:
					position = right
				else:
					position = left

				if position < 0:
					return resultList

			self.collectFromLow(left, dataSet, low, resultList)
			resultList.append(currentNode)
			self.collectFromHigh(right, dataSet, high, resultList)
			return resultList

	cdef void collectFromLow(self, i64 position, RecordNode dataSet, int low, list resultList):
		cdef i64 nodePosition, left, right
		cdef DataSet currentNode
		cdef int cmpLow

		while position >= 0:
			self.io.seek(position)
			self.io.read(&self.stream, BST_NODE_OFFSET)
			nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
			left = (<i64*> getBuffer(&self.stream, 8))[0]
			right = (<i64*> getBuffer(&self.stream, 8))[0]
			currentNode = self.readNodeKey(nodePosition, None)

			cmpLow = currentNode.compareIntToRecord(dataSet, low)

			if cmpLow == 1:
				self.collectFromLow(left, dataSet, low, resultList)
				resultList.append(currentNode)
				self.collectSubTree(right, resultList)
				return
			else:
				position = right

	cdef void collectFromHigh(self, i64 position, RecordNode dataSet, int high, list resultList):
		cdef i64 nodePosition, left, right
		cdef DataSet currentNode
		cdef int cmpHigh

		while position >= 0:
			self.io.seek(position)
			self.io.read(&self.stream, BST_NODE_OFFSET)
			nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
			left = (<i64*> getBuffer(&self.stream, 8))[0]
			right = (<i64*> getBuffer(&self.stream, 8))[0]
			currentNode = self.readNodeKey(nodePosition, None)

			cmpHigh = currentNode.compareIntToRecord(dataSet, high)

			if cmpHigh == 0:
				self.collectSubTree(left, resultList)
				resultList.append(currentNode)
				self.collectFromHigh(right, dataSet, high, resultList)
				return
			else:
				position = left


