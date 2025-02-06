from xtore.common.Buffer cimport Buffer, setBuffer, setBoolean, getBuffer, getBoolean, initBuffer, releaseBuffer
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.HashIterator cimport HashIterator
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.TimeUtil cimport getMicroTime
from xtore.BaseType cimport u32, i32, i64, f64

from libc.string cimport memcpy, memcmp
from libc.stdlib cimport malloc, free

cdef char *MAGIC = "@XT_HASH" 
cdef int MAGIC_LENGTH = 8
cdef i32 HASH_SIZE = 16
cdef i32 TREE_SIZE = 32
cdef i32 BLOCK_SIZE = 1 << 14
cdef i32 REST_SIZE = (1 << 12) - 1
cdef i32 HASH_LAYER = 15
cdef i32 PAGE_SIZE = 1 << 15
cdef i32 HASH_STORAGE_HEADER_SIZE = 29 + MAGIC_LENGTH + HASH_LAYER*8
cdef i32 HASH_PAGE_SIZE = 1 << 16
cdef i32 HASH_PAGE_ITEM_SIZE = 8

cdef i32 NOT_FOUND_AND_SET = 0
cdef i32 FOUND_AND_SET = 1
cdef i32 NOT_SET = 2

cdef class HashStorage (BasicStorage):
	def __init__(self, StreamIOHandler io, CollisionMode mode):
		self.mode = mode
		self.headerSize = HASH_STORAGE_HEADER_SIZE
		self.name = None
		self.io = io
		self.layer = -1
		self.position = -1
		self.pageStorage = LinkedPageStorage(io, HASH_PAGE_SIZE, HASH_PAGE_ITEM_SIZE)
		self.comparingNode = None
		self.isIterable = False
		self.isCreated = False
			
		initBuffer(&self.stream, <char *> malloc(TREE_SIZE), TREE_SIZE)
		initBuffer(&self.pageStream, <char *> malloc(PAGE_SIZE), PAGE_SIZE)
		initBuffer(&self.headerStream, <char *> malloc(HASH_STORAGE_HEADER_SIZE), HASH_STORAGE_HEADER_SIZE)

		self.layerModulus = <i64 *> malloc(8*HASH_LAYER)
		self.layerSize = <i64 *> malloc(8*HASH_LAYER)
		self.layerPosition = <i64 *> malloc(8*HASH_LAYER)
		self.n = 0

		cdef u32 i
		cdef u32 m = 1
		cdef i64 padding = -1
		for i in range(PAGE_SIZE//8):
			setBuffer(&self.pageStream, <char *> &padding, 8)

		for i in range(HASH_LAYER):
			self.layerModulus[i] = m*BLOCK_SIZE+REST_SIZE
			self.layerSize[i] = self.layerModulus[i]*HASH_SIZE
			if i > 0: self.layerSize[i] = self.layerSize[i] + self.layerSize[i-1]
			m += 2
	
	def __dealloc__(self):
		releaseBuffer(&self.stream)
		releaseBuffer(&self.pageStream)
		releaseBuffer(&self.headerStream)
		if self.layerModulus != NULL:
			free(self.layerModulus)
			self.layerModulus = NULL
		if self.layerSize != NULL:
			free(self.layerSize)
			self.layerSize = NULL
		if self.layerPosition != NULL:
			free(self.layerPosition)
			self.layerPosition = NULL
	
	cdef enableIterable(self):
		if not self.isCreated: self.isIterable = True

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		self.layer = -1
		self.treePosition = -1
		self.pagePosition = -1
		for i in range(1, HASH_LAYER):
			self.layerPosition[i] = -1
		self.lastUpdate = getMicroTime()
		self.writeHeader()
		self.pageStorage.create()
		self.pagePosition = self.pageStorage.rootPosition
		self.expandLayer(1)
		self.isCreated = True
		return self.rootPosition

	cdef writeHeader(self):
		self.headerStream.position = 0
		self.writeHeaderBuffer(&self.headerStream)
		self.io.seek(self.rootPosition)
		self.io.write(&self.headerStream)
		self.isCreated = True
	
	cdef writeHeaderBuffer(self, Buffer *stream):
		setBuffer(stream, MAGIC, MAGIC_LENGTH)
		setBuffer(stream, <char *> &self.layer, 4)
		setBuffer(stream, <char *> &self.treePosition, 8)
		setBuffer(stream, <char *> &self.pagePosition, 8)
		setBuffer(stream, <char *> &self.lastUpdate, 8)
		setBoolean(stream, self.isIterable)
		setBuffer(stream, <char *> self.layerPosition, 8*HASH_LAYER)

	cdef readHeader(self, i64 rootPosition):
		self.rootPosition = rootPosition
		self.io.seek(self.rootPosition)
		self.io.read(&self.headerStream, self.headerSize)
		self.readHeaderBuffer(&self.headerStream)
		self.pageStorage.readHeader(self.pagePosition)
	
	cdef readHeaderBuffer(self, Buffer *stream):
		cdef bint isMagic = memcmp(MAGIC, self.headerStream.buffer, MAGIC_LENGTH)
		self.headerStream.position += MAGIC_LENGTH
		if isMagic != 0:
			raise ValueError('Wrong Magic for HashStorage')
		self.layer = (<i32 *> getBuffer(&self.headerStream, 4))[0]
		self.treePosition = (<i64 *> getBuffer(&self.headerStream, 8))[0]
		self.pagePosition = (<i64 *> getBuffer(&self.headerStream, 8))[0]
		self.lastUpdate = (<f64 *> getBuffer(&self.headerStream, 8))[0]
		self.isIterable = getBoolean(&self.headerStream)
		memcpy(self.layerPosition, getBuffer(&self.headerStream, 8*HASH_LAYER), 8*HASH_LAYER)

	cdef RecordNode get(self, RecordNode reference, RecordNode result):
		if self.layer < 0: return None
		cdef i64 hashed = reference.hash()
		cdef RecordNode found = self.getBucket(hashed, reference, result)
		if found is not None: return found
		if self.layer < HASH_LAYER: return None
		found = self.getTreePage(hashed, reference, result)
		return found

	cdef set(self, RecordNode reference):
		cdef i64 hashed = reference.hash()
		cdef i32 setResult = self.setBucket(hashed, reference)
		if setResult == NOT_SET:
			setResult = self.setTreePage(hashed, reference)
		if setResult == NOT_FOUND_AND_SET: self.n += 1
		if self.isIterable and setResult == NOT_FOUND_AND_SET:
			self.pageStorage.appendValue(<char *> &reference.position)
		self.lastUpdate = getMicroTime()
	
	cdef BasicIterator createIterator(self):
		return HashIterator(self)
	
	cdef setComparingNode(self, RecordNode comparingNode):
		self.comparingNode = comparingNode
	
	cdef RecordNode getBucket(self, i64 hashed, RecordNode reference, RecordNode result):
		cdef i32 i
		cdef i32 m
		cdef i64 storedHash
		cdef i64 storedNode
		cdef i64 position
		cdef RecordNode stored
		for i in range(HASH_LAYER) :
			m = self.layerModulus[i]
			if i > self.layer: break
			position = self.layerPosition[i]+(hashed%m)*HASH_SIZE
			self.io.seek(position)
			self.io.read(&self.stream, HASH_SIZE)
			storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]
			if storedHash == - 1: break
			if storedHash == hashed :
				stored = self.readNodeKey(storedNode, result)
				if reference.isEqual(stored) :
					self.readNodeValue(stored)
					stored.position = storedNode
					return stored
		return None

	cdef int setBucket(self, i64 hashed, RecordNode node):
		cdef RecordNode stored
		cdef i64 storedHash = -1
		cdef i64 storedNode = -1
		cdef i64 position
		cdef i32 i
		cdef i32 j
		cdef i32 m
		for i in range(HASH_LAYER) :
			m = self.layerModulus[i]
			if i >= self.layer:
				self.expandLayer(i+1)
				position = self.layerPosition[i]+(hashed%m)*HASH_SIZE
				storedHash = -1
				storedNode = -1
				self.writeHeader()
			else:
				position = self.layerPosition[i]+(hashed%m)*HASH_SIZE
				self.io.seek(position)
				self.io.read(&self.stream, HASH_SIZE)
				storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
				storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]
			if storedHash == -1:
				self.appendNode(node)
				self.io.seek(position)
				self.stream.position = 0
				setBuffer(&self.stream, <char *> &hashed, 8)
				setBuffer(&self.stream, <char *> &node.position, 8)
				self.io.write(&self.stream)
				return NOT_FOUND_AND_SET
			elif storedHash == hashed:
				stored = self.readNodeKey(storedNode, self.comparingNode)
				if stored.isEqual(node) :
					node.position = storedNode
					self.writeNode(node)
					return FOUND_AND_SET
		return NOT_SET
	
	cdef i64 setTreeRoot(self, i64 hashed, RecordNode node):
		self.appendNode(node)
		cdef i64 padding = -1
		self.stream.position = 0
		setBuffer(&self.stream, <char *> &padding, 8)
		setBuffer(&self.stream, <char *> &padding, 8)
		setBuffer(&self.stream, <char *> &hashed, 8)
		setBuffer(&self.stream, <char *> &node.position, 8)
		cdef i64 position = self.io.getTail()
		self.io.tail = self.io.append(&self.stream)
		return position
	
	cdef int setTree(self, i64 hashed, RecordNode node, i64 rootPosition):
		cdef i64 position = rootPosition
		cdef i64 padding = -1
		cdef i64 left
		cdef i64 right
		cdef i64 storedHash
		cdef i64 storedNode
		cdef i64 tail
		cdef RecordNode stored
		cdef int layer = 0
		while True:
			self.io.seek(position)
			self.io.read(&self.stream, TREE_SIZE)
			left = (<i64 *> getBuffer(&self.stream, 8))[0]
			right = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]
			
			layer += 1
			if storedHash == hashed :
				stored = self.readNodeKey(storedNode, self.comparingNode)
				if stored.isEqual(node) :
					node.position = storedNode
					self.writeNode(node)
					return FOUND_AND_SET
			if hashed >= storedHash :
				if right < 0 :
					self.appendNode(node)
					tail = self.io.getTail()
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &hashed, 8)
					setBuffer(&self.stream, <char *> &node.position, 8)
					self.io.append(&self.stream)

					self.stream.position = 0
					setBuffer(&self.stream, <char *> &left, 8)
					setBuffer(&self.stream, <char *> &tail, 8)
					setBuffer(&self.stream, <char *> &storedHash, 8)
					setBuffer(&self.stream, <char *> &storedNode, 8)
					self.io.seek(position)
					self.io.write(&self.stream)
					return NOT_FOUND_AND_SET
				else :
					position = right
			else :
				if left < 0 :
					self.appendNode(node)
					tail = self.io.getTail()
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &hashed, 8)
					setBuffer(&self.stream, <char *> &node.position, 8)
					self.io.append(&self.stream)

					self.stream.position = 0
					setBuffer(&self.stream, <char *> &tail, 8)
					setBuffer(&self.stream, <char *> &right, 8)
					setBuffer(&self.stream, <char *> &storedHash, 8)
					setBuffer(&self.stream, <char *> &storedNode, 8)
					self.io.seek(position)
					self.io.write(&self.stream)
					return NOT_FOUND_AND_SET
				else :
					position = left
	
	cdef int setTreePage(self, i64 hashed, RecordNode node):
		if self.treePosition < 0 : self.createTreePage()
		cdef i64 modulus = hashed%self.layerModulus[HASH_LAYER-1]
		cdef i64 position = self.treePosition+(modulus)*8
		self.io.seek(position)
		self.io.read(&self.stream, 8)
		cdef i64 rootPosition = (<i64 *> getBuffer(&self.stream, 8))[0]
		if rootPosition < 0:
			rootPosition = self.setTreeRoot(hashed, node)
			self.io.seek(position)
			self.stream.position = 0
			setBuffer(&self.stream, <char *> &rootPosition, 8)
			self.io.write(&self.stream)
			return NOT_FOUND_AND_SET
		else :
			return self.setTree(hashed, node, rootPosition)
	
	cdef createTreePage(self):
		cdef i32 n = self.layerModulus[HASH_LAYER-1]*8
		self.treePosition = self.io.getTail()
		while True:
			if n < PAGE_SIZE:
				self.pageStream.position = n
				self.io.fill(&self.pageStream)
				self.pageStream.position = PAGE_SIZE
				break
			else:
				self.io.fill(&self.pageStream)
				n = n - PAGE_SIZE
	
	cdef RecordNode getTree(self, i64 hashed, RecordNode reference, RecordNode result, i64 rootPosition):
		cdef i64 position = rootPosition
		cdef i64 left
		cdef i64 right
		cdef i64 storedHash
		cdef i64 storedNode
		cdef RecordNode stored
		cdef int layer = 0
		while True :
			self.io.seek(position)
			self.io.read(&self.stream, TREE_SIZE)
			left = (<i64 *> getBuffer(&self.stream, 8))[0]
			right = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]

			layer += 1
			if storedHash == hashed :
				stored = self.readNodeKey(storedNode, result)
				if reference.isEqual(stored) :
					self.readNodeValue(stored)
					stored.position = storedNode
					return stored
				position = right
			elif hashed > storedHash :
				position = right
			else :
				position = left
			if position < 0 : break
		return None
	
	cdef RecordNode getTreePage(self, i64 hashed, RecordNode reference, RecordNode result):
		cdef i64 modulus = hashed%self.layerModulus[HASH_LAYER-1]
		cdef i64 position = self.treePosition+(modulus)*8
		self.io.seek(position)
		self.io.read(&self.stream, 8)
		cdef i64 rootPosition = (<i64 *> getBuffer(&self.stream, 8))[0]
		if rootPosition < 0 : return None
		return self.getTree(hashed, reference, result, rootPosition)
	
	cdef bint checkTailSize(self):
		return self.io.tail >= self.layerSize[HASH_LAYER-1]

	cdef expandLayer(self, i32 layer):
		cdef i64 n = self.layerModulus[layer-1]*HASH_SIZE
		self.layerPosition[layer-1] = self.io.getTail()
		print(f'>>> Expand layer {layer} {self.layerPosition[layer-1]} {self.name}')
		while True:
			if n < PAGE_SIZE:
				self.pageStream.position = n
				self.io.fill(&self.pageStream)
				self.pageStream.position = PAGE_SIZE
				break
			else:
				self.io.fill(&self.pageStream)
				n = n - PAGE_SIZE
		self.layer = layer
		self.writeHeader()
