from xtore.BaseType cimport u64, i32, i64, f32, f128
from xtore.common.Buffer cimport Buffer
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, setBuffer, setBoolean, getBuffer, getBoolean, initBuffer, releaseBuffer

from libc.stdlib cimport malloc
from libc.string cimport memcmp
from libc.math cimport log2, floor

cdef char *MAGIC = "@XT_RTST"
cdef i32 MAGIC_LENGTH = 8

cdef i32 RANGE_TREE_STORAGE_HEADER_SIZE = 56
cdef i32 PAGE_HEADER_SIZE = 48

cdef u64 ALL_ONE = (1 << 64) - 1

cdef inline i64 normalizeIndex(ScopeTreeStorage self, i32 maxDepth, f128 key):
	cdef i64 segment = 1
	# NOTE Use for loop to avoid multiplication
	for i in range(maxDepth-1):
		segment = segment << self.potence
	return <i64> (segment*(key - self.min)/self.width)

cdef inline i64 calculateLayerIndex(ScopeTreeStorage self, i32 maxDepth, i64 normalized, i32 layer):
	cdef i64 shifted = normalized
	for i in range(maxDepth-1-layer):
		shifted = shifted >> self.potence
	return shifted & self.modulus

cdef class ScopeTreeStorage (BasicStorage):
	def __init__(self, StreamIOHandler io, CollisionMode mode, i32 pageSize, f128 min, f128 max):
		self.io = io
		self.mode = mode
		self.headerSize = RANGE_TREE_STORAGE_HEADER_SIZE
		self.pageSize = pageSize
		self.maxDepth = 1
		cdef f32 potence = log2(pageSize)
		cdef f32 floored = floor(potence)
		if potence - floored != 0:
			raise ValueError("pageSize must be potent of 2 e.g. 2, 4, 8, 16, ...")
		self.potence = <i32> potence
		self.modulus = pageSize - 1
		self.min = min
		self.max = max
		self.width = (max - min)/pageSize
		self.pageBufferSize = pageSize*sizeof(i64) + PAGE_HEADER_SIZE
		self.comparingNode = self.createNode()
		initBuffer(&self.headerStream, <char *> malloc(RANGE_TREE_STORAGE_HEADER_SIZE), RANGE_TREE_STORAGE_HEADER_SIZE)
		initBuffer(&self.pageStream, <char *> malloc(self.pageBufferSize), self.pageBufferSize)
		initBuffer(&self.positionStream, <char *> malloc(16), 16)

		cdef i64 placeHolder = -1
		self.pageStream.position = PAGE_HEADER_SIZE
		for i in range(pageSize):
			setBuffer(&self.pageStream, <char *> &placeHolder, sizeof(i64))

	def __dealloc__(self):
		releaseBuffer(&self.headerStream)
		releaseBuffer(&self.pageStream)
		releaseBuffer(&self.positionStream)

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		self.writeHeader()
		self.rootPagePosition = self.createPage(self.min, self.width)
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
		setBuffer(stream, <char *> &self.pageSize, 4)
		setBuffer(stream, <char *> &self.maxDepth, 4)
		setBuffer(stream, <char *> &self.rootPagePosition, 8)
		setBuffer(stream, <char *> &self.min, 16)
		setBuffer(stream, <char *> &self.width, 16)

	cdef readHeader(self, i64 rootPosition):
		self.rootPosition = rootPosition
		self.io.seek(self.rootPosition)
		self.io.read(&self.headerStream, self.headerSize)
		self.readHeaderBuffer(&self.headerStream)

	cdef readHeaderBuffer(self, Buffer *stream):
		cdef bint isMagic = memcmp(MAGIC, self.headerStream.buffer, MAGIC_LENGTH)
		self.headerStream.position += MAGIC_LENGTH
		if isMagic != 0:
			raise ValueError('Wrong Magic for RageTreeStorage')
		cdef i32 pageSize = (<i32 *> getBuffer(stream, 4))[0]
		if self.pageSize != pageSize:
			raise ValueError('PageSize mismatched')
		self.maxDepth = (<i32 *> getBuffer(stream, 4))[0]
		self.rootPagePosition = (<i64 *> getBuffer(stream, 8))[0]
		self.min = (<f128 *> getBuffer(stream, 16))[0]
		self.width = (<f128 *> getBuffer(stream, 16))[0]
		self.max = self.min + self.width*self.pageSize

	cdef i64 createPage(self, f128 min, f128 width):
		cdef u64 childFlag = 0
		cdef u64 nodeFlag = 0
		cdef i64 position = self.io.getTail()
		self.pageStream.position = 0
		setBuffer(&self.pageStream, <char *> &childFlag, 8)
		setBuffer(&self.pageStream, <char *> &nodeFlag, 8)
		setBuffer(&self.pageStream, <char *> &min, 16)
		setBuffer(&self.pageStream, <char *> &width, 16)
		self.pageStream.position = self.pageBufferSize
		self.io.append(&self.pageStream)
		# print(300, position, min, width)
		return position
	
	cdef RecordNode get(self, RecordNode reference, RecordNode result):
		cdef i32 maxDepth = self.maxDepth
		cdef i64 normalized = normalizeIndex(self, self.maxDepth, reference.getRangeValue())
		cdef i64 current = self.rootPagePosition
		cdef i64 index
		cdef i64 child
		cdef RecordNode stored
		for i in range(maxDepth):
			index = calculateLayerIndex(self, maxDepth, normalized, i)

			self.io.seek(current)
			self.io.read(&self.pageStream, 16)
			childFlag = (<u64 *> getBuffer(&self.pageStream, 8))[0]
			nodeFlag = (<u64 *> getBuffer(&self.pageStream, 8))[0]

			position = current + PAGE_HEADER_SIZE + (index << 3)
			self.io.seek(position)
			self.io.read(&self.positionStream, 8)
			child = (<i64*> getBuffer(&self.positionStream, 8))[0]

			isChild = childFlag & (1 << index)
			if isChild:
				current = child
			else:
				isNode = nodeFlag & (1 << index)
				if isNode:
					stored = self.readNodeKey(child, result)
					if reference.compare(stored) == 0:
						self.readNodeValue(stored)
						return stored
					else:
						return None
				else:
					return None
	
	cdef set(self, RecordNode reference):
		cdef i32 maxDepth = self.maxDepth
		cdef i32 depth
		cdef i64 normalized = normalizeIndex(self, self.maxDepth, reference.getRangeValue())
		cdef i64 index
		cdef i64 current = self.rootPagePosition
		cdef i64 position
		cdef i64 child
		cdef f128 min
		cdef f128 width
		cdef u64 chileFlag
		cdef u64 nodeFlag
		cdef bint isChild
		cdef bint isNode
		cdef RecordNode stored
		
		for i in range(maxDepth):
			index = calculateLayerIndex(self, maxDepth, normalized, i)

			self.io.seek(current)
			self.io.read(&self.pageStream, 16)
			childFlag = (<u64 *> getBuffer(&self.pageStream, 8))[0]
			nodeFlag = (<u64 *> getBuffer(&self.pageStream, 8))[0]

			position = current + PAGE_HEADER_SIZE + (index << 3)
			isChild = childFlag & (1 << index)
			
			if isChild:
				self.io.seek(position)
				self.io.read(&self.positionStream, 8)
				child = (<i64*> getBuffer(&self.positionStream, 8))[0]
				current = child
			else:
				isNode = nodeFlag & (1 << index)
				if isNode:
					self.io.seek(position)
					self.io.read(&self.positionStream, 8)
					child = (<i64*> getBuffer(&self.positionStream, 8))[0]
					stored = self.readNodeKey(child, self.comparingNode)
					if reference.compare(stored) == 0:
						self.writeNode(reference)
					else:
						self.io.seek(current+16)
						self.io.read(&self.pageStream, 32)
						min = (<f128 *> getBuffer(&self.pageStream, 16))[0]
						width = (<f128 *> getBuffer(&self.pageStream, 16))[0]
						min = min + index*width
						width = width/self.pageSize
						
						childFlag = childFlag | (1 << index)
						nodeFlag = nodeFlag & (ALL_ONE - (1 << index))
						self.pageStream.position = 0
						setBuffer(&self.pageStream, <char *> &childFlag, 8)
						setBuffer(&self.pageStream, <char *> &nodeFlag, 8)
						self.io.seek(current)
						self.io.write(&self.pageStream)

						child = self.createPage(min, width)
						self.positionStream.position = 0
						setBuffer(&self.positionStream, <char *> &child, 8)
						self.io.seek(position)
						self.io.write(&self.positionStream)
						
						depth = i+2

						child = self.insertNode(child, stored, &depth)
						child = self.insertNode(child, reference, &depth)
						if depth > self.maxDepth: self.maxDepth = depth
				else:
					self.appendNode(reference)
					self.positionStream.position = 0
					setBuffer(&self.positionStream, <char *> &reference.position, 8)
					self.io.seek(position)
					self.io.write(&self.positionStream)

					nodeFlag = nodeFlag | (1 << index)
					self.pageStream.position = 0
					setBuffer(&self.pageStream, <char *> &nodeFlag, 8)
					self.io.seek(current + 8)
					self.io.write(&self.pageStream)
					# print(102, reference.position)
				break
	
	cdef i64 insertNode(self, i64 page, RecordNode node, i32 *depth):
		self.io.seek(page)
		self.io.read(&self.pageStream, PAGE_HEADER_SIZE)

		cdef u64 childFlag = (<u64 *> getBuffer(&self.pageStream, 8))[0]
		cdef u64 nodeFlag = (<u64 *> getBuffer(&self.pageStream, 8))[0]
		cdef f128 min = (<f128 *> getBuffer(&self.pageStream, 16))[0]
		cdef f128 width = (<f128 *> getBuffer(&self.pageStream, 16))[0]
		
		cdef i64 index = <i64> ((node.getRangeValue() - min)/width)
		cdef i64 position = page + PAGE_HEADER_SIZE + (index << 3)
		cdef i64 child
		cdef bint isChild = childFlag & (1 << index)
		cdef bint isNode = nodeFlag & (1 << index)

		if isNode:
			self.io.seek(position)
			self.io.read(&self.positionStream, 8)
			child = (<i64 *> getBuffer(&self.positionStream, 8))[0]

			min = min + index*width
			width = width/self.pageSize
			self.readNodeKey(child, self.comparingNode)

			childFlag = childFlag | (1 << index)
			nodeFlag = nodeFlag & (ALL_ONE - (1 << index))
			self.pageStream.position = 0
			setBuffer(&self.pageStream, <char *> &childFlag, 8)
			setBuffer(&self.pageStream, <char *> &nodeFlag, 8)
			self.io.seek(page)
			self.io.write(&self.pageStream)

			child = self.createPage(min, width)
			self.positionStream.position = 0
			setBuffer(&self.positionStream, <char *> &child, 8)
			self.io.seek(position)
			self.io.write(&self.positionStream)

			depth[0] = depth[0] + 1
			child = self.insertNode(child, self.comparingNode, depth)
			child = self.insertNode(child, node, depth)
			return child
		else:
			if node.position < 0: self.appendNode(node)
			self.positionStream.position = 0
			setBuffer(&self.positionStream, <char *> &node.position, 8)
			self.io.seek(position)
			self.io.write(&self.positionStream)

			nodeFlag = nodeFlag | (1 << index)
			self.pageStream.position = 0
			setBuffer(&self.pageStream, <char *> &nodeFlag, 8)
			self.io.seek(page + 8)
			self.io.write(&self.pageStream)
			return page
