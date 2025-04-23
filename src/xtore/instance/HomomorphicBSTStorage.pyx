from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer, setBuffer, getBuffer, initBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage
from libc.stdlib cimport malloc
from libc.string cimport memcmp

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

		# print()
		# print("start getting data at:", reference)

		while True:
			self.io.seek(position)
			self.io.read(&self.stream, BST_NODE_OFFSET)
			nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
			left = (<i64*> getBuffer(&self.stream, 8))[0]
			right = (<i64*> getBuffer(&self.stream, 8))[0]
			stored = self.readNodeKey(nodePosition, result)

			compareResult = reference.compare(stored)

			# print("left:",left, "right:",right)

			if compareResult == 1:
				if left > 0:
					position = left
					# print("Go left")
					# print()
				else:
					# print("return:", stored)
					# print()
					return stored

			else:
				if right > 0:
					position = right
					# print("Go right")
					# print()
				else:
					# print("return:", stored)
					# print()
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
			# print("Created root node at position", self.rootNodePosition)
			return
		
		cdef i64 position = self.rootNodePosition
		cdef i64 nodePosition
		cdef i64 left
		cdef i64 right
		cdef i32 compareResult
		cdef RecordNode stored
		while True:
			# print("\nCurrent node position:", position)
			self.io.seek(position)
			self.io.read(&self.stream, BST_NODE_OFFSET)
			nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
			left = (<i64*> getBuffer(&self.stream, 8))[0]
			right = (<i64*> getBuffer(&self.stream, 8))[0]
			# print(f"Node at {position}: left={left}, right={right}")
			stored = self.readNodeKey(nodePosition, self.comparingNode)


			compareResult = reference.compare(stored)

			if compareResult == 1:
				if left > 0:
					position = left
					# print("Go left")
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
					# print("appendNode left")
					break
			else:
				if right > 0:
					position = right
					# print("Go right")
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
					# print("appendNode right")
					break

	cdef list getRangeData(self, RecordNode low, RecordNode high):
		if self.rootNodePosition < 0: return None
		cdef i64 nodePosition
		cdef i64 left
		cdef i64 right
		cdef RecordNode currentNode
		cdef list resultList = []

		cdef i64 position = self.rootNodePosition

		print()

		while True:

			left, right, position, currentNode = self.readNode(position)

			lowCompareResult = low.compare(currentNode)
			highCompareResult = high.compare(currentNode)
			print("lowCompare:", lowCompareResult, "highCompare:", highCompareResult)

			if lowCompareResult == 1 and highCompareResult == 0:
				break

			elif highCompareResult == 0:
				print("go right")
				position = right
			else:
				print("go left")
				position = left

			if position < 0:
				print("Invalid position, breaking")
				break
			
		print("LCAnode:", currentNode, "position:", position)

		print()
		print("start collecting data")

		print("left side")
		print("currentNode:", currentNode, "position:", position, "left:", left, "right:", right)

		self.collectGreater(left, low, resultList)

		if lowCompareResult == 1 and highCompareResult == 0:
			resultList.append(currentNode)

		self.collectLess(right, high, resultList)
		
		return resultList

	cdef void collectGreater(self, i64 position, RecordNode low, list result):
		cdef i64 nodePosition, left, right
		cdef RecordNode currentNode

		while position >= 0:
			left, right, position, currentNode = self.readNode(position)
	
			if low.compare(currentNode) == 1:
				self.collectGreater(left, low, result)
				result.append(currentNode)
				position = right
			else:
				position = right
				print("Skip left subtree go right")


	cdef void collectLess(self, i64 position, RecordNode high, list result):
		cdef i64 nodePosition, left, right
		cdef RecordNode currentNode
		print("----collecting less data")

		while position >= 0:
			left, right, position, currentNode = self.readNode(position)
			print("currentNode:", currentNode, "position:", position, "left:", left, "right:", right)

			if high.compare(currentNode) == 0:
				position = left
				result.append(currentNode)
				self.collectLess(right, high, result)
			else:
				position = left
				print("Skip right subtree go left")

	cdef tuple readNode(self, i64 position):
		cdef i64 nodePosition, left, right
		cdef RecordNode currentNode
		if position < 0: return (-1, -1, -1, None)

		self.io.seek(position)
		self.io.read(&self.stream, BST_NODE_OFFSET)
		nodePosition = (<i64*> getBuffer(&self.stream, 8))[0]
		left = (<i64*> getBuffer(&self.stream, 8))[0]
		right = (<i64*> getBuffer(&self.stream, 8))[0]
		currentNode = self.readNodeKey(nodePosition, None)

		return (left, right, position, currentNode)


