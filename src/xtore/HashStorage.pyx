from xtore.Buffer cimport Buffer, setBuffer, getBuffer, initBuffer, releaseBuffer
from xtore.HashNode cimport HashNode
from xtore.StreamIOHandler cimport StreamIOHandler
from xtore.BaseType cimport u32, i32, i64

from libc.string cimport memcpy
from libc.stdlib cimport malloc, free

cdef i32 HASH_SIZE = 16
cdef i32 TREE_SIZE = 32
cdef i32 BLOCK_SIZE = 1 << 14
cdef i32 REST_SIZE = (1 << 12) - 1
cdef i32 HASH_LAYER = 15
cdef i32 PAGE_SIZE = 1 << 15
cdef i32 HEADER_SIZE = 4 + HASH_LAYER*8

cdef class HashStorage:
	def __init__(self, StreamIOHandler io):
		self.headerSize = HEADER_SIZE
		self.io = io
		self.layer = -1
		self.position = -1
			
		initBuffer(&self.stream, <char *> malloc(TREE_SIZE), TREE_SIZE)
		initBuffer(&self.pageStream, <char *> malloc(PAGE_SIZE), PAGE_SIZE)
		initBuffer(&self.headerStream, <char *> malloc(HEADER_SIZE), HEADER_SIZE)

		self.layerModulus = <i64 *> malloc(8*HASH_LAYER)
		self.layerSize = <i64 *> malloc(8*HASH_LAYER)
		self.layerPosition = <i64 *> malloc(8*HASH_LAYER)

		cdef u32 i
		cdef u32 m
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

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		self.layer = -1
		for i in range(HASH_LAYER):
			self.layerPosition[i] = -1
		self.writeHeader()
		return self.rootPosition

	cdef writeHeader(self):
		self.headerStream.position = 0
		setBuffer(&self.headerStream, <char *> &self.layer, 4)
		setBuffer(&self.headerStream, <char *> self.layerPosition, 8*HASH_LAYER)
		self.io.seek(self.rootPosition)
		self.io.write(&self.headerStream)

	cdef readHeader(self, i64 rootPosition):
		self.rootPosition = rootPosition
		self.io.seek(self.rootPosition)
		self.io.read(&self.headerStream, HEADER_SIZE)
		self.layer = (<i32 *> getBuffer(&self.headerStream, 4))[0]
		memcpy(self.layerPosition, getBuffer(&self.headerStream, 8*HASH_LAYER), 8*HASH_LAYER)
	
	cdef HashNode get(self, HashNode reference):
		if self.layer < 0: return None
		cdef i64 hashed = reference.hash()
		cdef HashNode found = self.getBucket(hashed, reference)
		if found is not None: return found
		if self.layer < HASH_LAYER: return None
		found = self.getTreePage(hashed, reference)
		return found

	cdef set(self, HashNode reference):
		cdef i64 hashed = reference.hash()
		print(301, hashed)
		cdef bint isBucket = self.setBucket(hashed, reference)
		print(302, isBucket)
		if isBucket: return
		print(303)
		self.setTreePage(hashed, reference)
		print(304)
	
	cdef HashNode getBucket(self, i64 hashed, HashNode reference):
		cdef i32 i
		cdef i32 m
		cdef i64 storedHash
		cdef i64 storedNode
		cdef i64 position
		for i in range(HASH_LAYER) :
			print(201, i, hashed, self.layer)
			m = self.layerModulus[i]
			if i > self.layer: break
			position = self.layerPosition[i]+(hashed%m)*HASH_SIZE
			self.io.seek(position)
			self.io.read(&self.stream, HASH_SIZE)
			storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]
			print(202, storedHash, storedNode)
			if storedHash == - 1: break
			if storedHash == hashed :
				stored = self.readNodeKey(storedNode)
				if reference.isEqual(stored) :
					self.readNodeValue(stored)
					return stored
		return None

	cdef bint setBucket(self, i64 hashed, HashNode node):
		cdef HashNode stored
		cdef i64 storedHash = -1
		cdef i64 storedNode = -1
		cdef i64 position
		cdef i32 i
		cdef i32 j
		cdef i32 m
		
		for i in range(HASH_LAYER) :
			m = self.layerModulus[i]
			position = self.layerPosition[i]+(hashed%m)*HASH_SIZE
			if i > self.layer :
				self.layer = i
				self.expandLayer(i)
				storedHash = -1
				storedNode = -1
				self.writeHeader()
			else :
				self.io.seek(position)
				self.io.read(&self.stream, HASH_SIZE)
				storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
				storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]

			if storedHash == -1 :
				self.appendNode(node)
				self.io.seek(position)
				self.stream.position = 0
				setBuffer(&self.stream, <char *> &hashed, 8)
				setBuffer(&self.stream, <char *> &node.position, 8)
				self.io.write(&self.stream)
				return True
			elif storedHash == hashed :
				stored = self.readNodeKey(storedNode)
				if stored.isEqual(node) :
					node.position = storedNode
					self.writeNode(node)
					return True
		return False
	
	cdef i64 setTreeRoot(self, i64 hashed, HashNode node):
		self.appendNode(node)
		cdef i64 padding
		self.stream.position = 0
		setBuffer(&self.stream, <char *> &padding, 8)
		setBuffer(&self.stream, <char *> &padding, 8)
		setBuffer(&self.stream, <char *> &hashed, 8)
		setBuffer(&self.stream, <char *> &node.position, 8)
		self.io.tail = self.io.append(&self.stream)
		return self.io.tail
	
	cdef setTree(self, i64 hashed, HashNode node):
		cdef i64 position = self.layerSize[HASH_LAYER-1]
		cdef i64 padding = -1
		cdef i64 left
		cdef i64 right
		cdef i64 storedHash
		cdef i64 storedNode
		cdef i64 tail
		cdef HashNode stored
		while True:
			self.io.seek(position)
			self.io.read(&self.stream, TREE_SIZE)
			left = (<i64 *> getBuffer(&self.stream, 8))[0]
			right = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]
			
			if storedHash == hashed :
				stored = self.readNodeKey(storedNode)
				if stored.isEqual(node) :
					node.position = storedNode
					self.writeNode(node)
					break
			if hashed >= storedHash :
				if right < 0 :
					tail = self.io.tail
					self.appendNode(node)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &hashed, 8)
					setBuffer(&self.stream, <char *> &node.position, 8)
					self.io.tail = self.io.append(&self.stream)

					self.io.seek(position)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &left, 8)
					setBuffer(&self.stream, <char *> &tail, 8)
					setBuffer(&self.stream, <char *> &storedHash, 8)
					setBuffer(&self.stream, <char *> &storedNode, 8)
					self.io.write(&self.stream)
					break
				else :
					position = right
			else :
				if left < 0 :
					tail = self.io.tail
					self.appendNode(node)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &padding, 8)
					setBuffer(&self.stream, <char *> &hashed, 8)
					setBuffer(&self.stream, <char *> &node.position, 8)
					self.io.tail = self.io.append(&self.stream)

					self.io.seek(position)
					self.stream.position = 0
					setBuffer(&self.stream, <char *> &tail, 8)
					setBuffer(&self.stream, <char *> &right, 8)
					setBuffer(&self.stream, <char *> &storedHash, 8)
					setBuffer(&self.stream, <char *> &storedNode, 8)
					self.io.write(&self.stream)
					break
				else :
					position = left
	
	cdef setTreePage(self, i64 hashed, HashNode node):
		if self.io.tail == self.layerSize[HASH_LAYER-1] : self.createTreePage()
		cdef i64 position = self.layerSize[HASH_LAYER-1]+(hashed%self.layerModulus[HASH_LAYER-1])*8
		self.io.seek(position)
		self.io.read(&self.stream, 8)
		cdef i64 rootPosition = (<i64 *> getBuffer(&self.stream, 8))[0]
		if rootPosition < 0 :
			rootPosition = self.setTreeRoot(hashed, node)
			self.io.seek(position)
			self.stream.position = 0
			setBuffer(&self.stream, <char *> &rootPosition, 8)
			self.io.write(&self.stream)
		else :
			self.setTree(hashed, node)
	
	cdef createTreePage(self):
		cdef i32 n = self.layerModulus[HASH_LAYER-1]*8
		while True:
			if n < PAGE_SIZE:
				self.pageStream.position = n
				self.io.fill(&self.pageStream)
				self.pageStream.position = PAGE_SIZE
				break
			else:
				self.io.fill(&self.pageStream)
				n = n - PAGE_SIZE
	
	cdef HashNode getTree(self, i64 hashed, HashNode reference, i64 rootPosition):
		cdef i64 position = rootPosition
		cdef i64 left
		cdef i64 right
		cdef i64 storedHash
		cdef i64 storedNode
		cdef HashNode stored
		while True :
			self.io.seek(position)
			self.io.read(&self.stream, TREE_SIZE)
			left = (<i64 *> getBuffer(&self.stream, 8))[0]
			right = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedHash = (<i64 *> getBuffer(&self.stream, 8))[0]
			storedNode = (<i64 *> getBuffer(&self.stream, 8))[0]
			if storedHash == hashed :
				stored = self.readNodeKey(storedNode)
				if reference.isEqual(stored) :
					self.readNodeValue(stored)
					return stored
				position = right
			elif hashed > storedHash :
				position = right
			else :
				position = left
			if position < 0 : break
		return None
	
	cdef HashNode getTreePage(self, i64 hashed, HashNode reference):
		cdef i64 position = self.layerSize[HASH_LAYER-1]+(hashed%self.layerModulus[HASH_LAYER-1])*8
		self.io.seek(position)
		self.io.read(&self.stream, 8)
		cdef i64 rootPosition = (<i64 *> getBuffer(&self.stream, 8))[0]
		if rootPosition < 0 : return None
		return self.getTree(hashed, reference, rootPosition)
	
	cdef bint checkTailSize(self):
		return self.io.tail >= self.layerSize[HASH_LAYER-1]

	cdef expandLayer(self, i32 layer):
		cdef i32 n = self.layerModulus[layer]*HASH_SIZE
		self.layerPosition[layer] = self.io.getTail()
		while True:
			if n < PAGE_SIZE:
				self.pageStream.position = n
				self.io.fill(&self.pageStream)
				self.pageStream.position = PAGE_SIZE
				break
			else:
				self.io.fill(&self.pageStream)
				n = n - PAGE_SIZE
		self.writeHeader()

	cdef appendNode(self, HashNode node):
		raise NotImplementedError
	
	cdef HashNode readNodeKey(self, i64 position):
		raise NotImplementedError
	
	cdef readNodeValue(self, HashNode node):
		raise NotImplementedError
	
	cdef writeNode(self, HashNode node):
		raise NotImplementedError
