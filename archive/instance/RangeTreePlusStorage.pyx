from xtore.BaseType cimport u8, u64, i32, i64, f32, f128
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

cdef inline i64 normalizeIndex(ScopeTreePlusStorage self, i32 maxDepth, f128 key):
	cdef i64 segment = 1
	# NOTE Use for loop to avoid multiplication
	for i in range(maxDepth-1):
		segment = segment << self.potence
	return <i64> (segment*(key - self.min)/self.width)

cdef inline i64 calculateLayerIndex(ScopeTreePlusStorage self, i32 maxDepth, i64 normalized, i32 layer):
	cdef i64 shifted = normalized
	for i in range(maxDepth-1-layer):
		shifted = shifted >> self.potence
	return shifted & self.modulus

cdef class ScopeTreePlusStorage (BasicStorage):
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
		self.pageBufferSize = 4*pageSize*sizeof(i64)
		self.comparingNode = self.createNode()
		initBuffer(&self.headerStream, <char *> malloc(RANGE_TREE_STORAGE_HEADER_SIZE), RANGE_TREE_STORAGE_HEADER_SIZE)
		initBuffer(&self.pageStream, <char *> malloc(self.pageBufferSize), self.pageBufferSize)
		initBuffer(&self.positionStream, <char *> malloc(32), 32)

		cdef i64 placeHolder = -1
		cdef f128 key = 0.0
		self.pageStream.position = 0
		for i in range(pageSize):
			setBuffer(&self.pageStream, <char *> &placeHolder, 8)
			setBuffer(&self.pageStream, <char *> &placeHolder, 8)
			setBuffer(&self.pageStream, <char *> &key, 16)

	def __dealloc__(self):
		releaseBuffer(&self.headerStream)
		releaseBuffer(&self.pageStream)
		releaseBuffer(&self.positionStream)

	cdef i64 create(self):
		self.rootPosition = self.io.getTail()
		self.writeHeader()
		self.rootPagePosition = self.createPage()
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

	cdef i64 createPage(self):
		cdef i64 position = self.io.getTail()
		self.pageStream.position = 0
		self.pageStream.position = self.pageBufferSize
		self.io.append(&self.pageStream)
		return position
	
	cdef RecordNode get(self, RecordNode reference, RecordNode result):
		cdef i32 maxDepth = self.maxDepth
		cdef i64 normalized = normalizeIndex(self, self.maxDepth, reference.getRangeValue())
		cdef i64 current = self.rootPagePosition
		cdef i64 index
		cdef i64 child
		cdef i64 item
		cdef f128 key
		cdef f128 referenceKey = reference.getRangeValue()
		cdef RecordNode stored
		for i in range(maxDepth):
			index = calculateLayerIndex(self, maxDepth, normalized, i)
			position = current + (index << 5)
			self.io.seek(position)
			self.io.read(&self.positionStream, 32)
			child = (<i64*> getBuffer(&self.positionStream, 8))[0]
			item = (<i64*> getBuffer(&self.positionStream, 8))[0]
			key = (<f128*> getBuffer(&self.positionStream, 16))[0]
			# print(201, normalized, index, current, position, child, item, reference)
			if key == referenceKey:
				stored = self.readNodeKey(item, result)
				self.readNodeValue(stored)
				return stored
			elif child >= 0:
				current = child
			else:
				return None
	
	cdef set(self, RecordNode reference):
		cdef i32 depth
		cdef i64 normalized = normalizeIndex(self, self.maxDepth, reference.getRangeValue())
		cdef i64 current = self.rootPagePosition
		cdef i64 index
		cdef i64 position
		cdef i64 child
		cdef i64 item
		cdef f128 key
		cdef f128 referenceKey = reference.getRangeValue()
		cdef RecordNode stored
		
		for i in range(self.maxDepth):
			index = calculateLayerIndex(self, self.maxDepth, normalized, i)
			position = current + (index << 5)
			self.io.seek(position)
			self.io.read(&self.positionStream, 32)
			child = (<i64*> getBuffer(&self.positionStream, 8))[0]
			item = (<i64*> getBuffer(&self.positionStream, 8))[0]
			key = (<f128*> getBuffer(&self.positionStream, 16))[0]

			# print(101, normalized, index, current, child, item, reference)
			if key == referenceKey:
				self.writeNode(reference)
			elif child >= 0:
				# print(102, current, child)
				current = child
			else:
				if item >= 0:
					child = self.createPage()
					depth = i+2
					self.insertNode(child, reference, depth)
					self.positionStream.position = 0
					setBuffer(&self.positionStream, <char *> &child, 8)
					# setBuffer(&self.positionStream, <char *> &item, 8)
					self.io.seek(position)
					self.io.write(&self.positionStream)
					
					# print(103, child, reference.position, stored, reference)
					if depth > self.maxDepth: self.maxDepth = depth
				else:
					self.appendNode(reference)
					self.positionStream.position = 0
					# setBuffer(&self.positionStream, <char *> &child, 8)
					setBuffer(&self.positionStream, <char *> &reference.position, 8)
					setBuffer(&self.positionStream, <char *> &referenceKey, 16)
					self.io.seek(position+8)
					self.io.write(&self.positionStream)
					# print(105, reference.position, reference, position)
				break
	
	cdef insertNode(self, i64 page, RecordNode node, i32 depth):
		cdef f128 rangeValue = node.getRangeValue()
		cdef f128 width = self.width/(1 << ((depth-1)*self.potence))
		cdef i64 normalized = normalizeIndex(self, depth, rangeValue)
		cdef i64 index = calculateLayerIndex(self, depth, normalized, depth-1)
		cdef i64 position = page + (index << 5)
		cdef i64 placeHolder = -1
		cdef f128 key = node.getRangeValue()
		# print(301, normalized, index, page)
		self.appendNode(node)
		self.positionStream.position = 0
		setBuffer(&self.positionStream, <char *> &placeHolder, 8)
		setBuffer(&self.positionStream, <char *> &node.position, 8)
		setBuffer(&self.positionStream, <char *> &key, 16)
		self.io.seek(position)
		self.io.write(&self.positionStream)
		# print(302, node.position, node)
