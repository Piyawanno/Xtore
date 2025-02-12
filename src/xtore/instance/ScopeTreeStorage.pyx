from xtore.BaseType cimport u8, u64, i32, i64, f32, f128
from xtore.common.Buffer cimport Buffer
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.ScopeIterator cimport ScopeIterator
from xtore.instance.ScopeBackwardIterator cimport ScopeBackwardIterator
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, setBuffer, setBoolean, getBuffer, getBoolean, initBuffer, releaseBuffer

from libc.stdlib cimport malloc
from libc.string cimport memcmp
from libc.math cimport log2, floor

cdef char *MAGIC = "@XT_RTST"
cdef i32 MAGIC_LENGTH = 8

cdef i32 RANGE_TREE_STORAGE_HEADER_SIZE = 56

cdef class ScopeTreeStorage (BasicStorage):
	def __init__(
		self,
		StreamIOHandler io,
		i32 pageSize=64,
		ScopeRootMode rootMode=ScopeRootMode.MIDDLE,
		CollisionMode mode=CollisionMode.REPLACE,
	):
		self.io = io
		self.mode = mode
		self.rootMode = rootMode
		self.headerSize = RANGE_TREE_STORAGE_HEADER_SIZE
		self.pageSize = pageSize
		self.maxDepth = 1
		cdef f32 potence = log2(pageSize)
		cdef f32 floored = floor(potence)
		if potence - floored != 0:
			raise ValueError("pageSize must be potent of 2 e.g. 2, 4, 8, 16, ...")
		self.potence = <i32> potence
		self.modulus = pageSize - 1
		self.pageBufferSize = pageSize*sizeof(i64)
		self.comparingNode = self.createNode()
		initBuffer(&self.headerStream, <char *> malloc(RANGE_TREE_STORAGE_HEADER_SIZE), RANGE_TREE_STORAGE_HEADER_SIZE)
		initBuffer(&self.pageStream, <char *> malloc(self.pageBufferSize), self.pageBufferSize)
		initBuffer(&self.positionStream, <char *> malloc(16), 16)

		cdef u64 placeHolder = 0
		cdef u8 state = OccupationState.FREE
		placeHolder = (placeHolder << 2) | state
		self.pageStream.position = 0
		for i in range(pageSize):
			setBuffer(&self.pageStream, <char *> &placeHolder, 8)

	def __dealloc__(self):
		releaseBuffer(&self.headerStream)
		releaseBuffer(&self.pageStream)
		releaseBuffer(&self.positionStream)

	cdef i64 create(self):
		self.min = self.getInitialMinValue()
		self.max = self.getInitialMaxValue()
		self.width = (self.max - self.min)/self.pageSize
		self.rootPosition = self.io.getTail()
		self.writeHeader()
		self.rootPagePosition = self.createPage()
		self.writeHeader()
		return self.rootPosition

	cdef BasicIterator createIterator(self):
		return ScopeIterator(self)

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
			raise ValueError('Wrong Magic for ScopeTreeStorage')
		cdef i32 pageSize = (<i32 *> getBuffer(stream, 4))[0]
		if self.pageSize != pageSize:
			raise ValueError('PageSize mismatched')
		self.maxDepth = (<i32 *> getBuffer(stream, 4))[0]
		self.rootPagePosition = (<i64 *> getBuffer(stream, 8))[0]
		self.min = (<f128 *> getBuffer(stream, 16))[0]
		self.width = (<f128 *> getBuffer(stream, 16))[0]
		self.max = self.min + self.width*self.pageSize

	cdef u64 createPage(self):
		cdef i64 position = self.io.getTail()
		self.pageStream.position = self.pageBufferSize
		self.io.append(&self.pageStream)
		return <u64> position
	
	cdef f128 getInitialMinValue(self):
		raise NotImplementedError

	cdef f128 getInitialMaxValue(self):
		raise NotImplementedError
	
	cdef i32 getDepth(self):
		return self.maxDepth
	
	cdef RecordNode get(self, RecordNode reference, RecordNode result):
		cdef i32 maxDepth = self.maxDepth
		cdef i64 normalized = normalizeIndex(self, self.maxDepth, reference.getRangeValue())
		cdef i64 current = self.rootPagePosition
		cdef i64 position
		cdef i64 index
		cdef u64 child
		cdef u64 meta
		cdef u8 state
		cdef RecordNode stored
		
		for i in range(maxDepth):
			index = calculateLayerIndex(self, maxDepth, normalized, i)
			position = current + (index << 3)
			self.io.seek(position)
			self.io.read(&self.positionStream, 8)
			meta = (<u64*> getBuffer(&self.positionStream, 8))[0]
			state = meta &  3
			child = meta >> 2
			if state == OccupationState.PAGE:
				current = child
			elif state == OccupationState.NODE:
				stored = self.readNodeKey(child, result)
				if reference.compare(stored) != 0: return None
				self.readNodeValue(stored)
				return stored
			else:
				return None
	
	cdef set(self, RecordNode reference):
		cdef f128 key = reference.getRangeValue()
		cdef i32 maxDepth = self.maxDepth
		while key < self.min or key >= self.max:
			self.createParent()
		cdef i32 depth
		cdef i64 normalized = normalizeIndex(self, self.maxDepth, key)
		cdef i64 current = self.rootPagePosition
		cdef i64 index
		cdef i64 position
		cdef u64 child
		cdef u64 meta
		cdef u8 state
		cdef RecordNode stored
		
		for i in range(self.maxDepth):
			index = calculateLayerIndex(self, self.maxDepth, normalized, i)
			position = current + (index << 3)
			self.io.seek(position)
			self.io.read(&self.positionStream, 8)
			meta = (<u64*> getBuffer(&self.positionStream, 8))[0]
			state = meta &  3
			child = meta >> 2

			if state == OccupationState.FREE:
				self.appendNode(reference)
				state = OccupationState.NODE
				self.positionStream.position = 0
				meta = <u64> reference.position
				meta = (meta << 2) | state
				setBuffer(&self.positionStream, <char *> &meta, 8)
				self.io.seek(position)
				self.io.write(&self.positionStream)
				break
			elif state == OccupationState.PAGE:
				current = child
			else:
				stored = self.readNodeKey(child, self.comparingNode)
				if reference.compare(stored) == 0:
					self.writeNode(reference)
					return
				state = OccupationState.PAGE
				child = self.createPage()
				self.positionStream.position = 0
				meta = (child << 2) | state
				setBuffer(&self.positionStream, <char *> &meta, 8)
				self.io.seek(position)
				self.io.write(&self.positionStream)

				depth = i+2
				child = self.insertNode(child, stored, &depth)
				child = self.insertNode(child, reference, &depth)
				if depth > self.maxDepth: self.maxDepth = depth
				break
		if self.maxDepth != maxDepth: self.writeHeader()
	
	cdef u64 createParent(self):
		cdef u64 position = self.createPage()
		cdef i32 half = self.pageSize >> 1
		cdef i32 index
		self.width = self.width*self.pageSize
		if self.rootMode == ScopeRootMode.RIGHT: self.min = self.min + self.width*half
		elif self.rootMode == ScopeRootMode.MIDDLE: self.min = self.min - self.width*half	
		cdef u64 nodePosition
		if self.rootMode == ScopeRootMode.LEFT:
			nodePosition = position
		elif self.rootMode == ScopeRootMode.RIGHT:
			nodePosition = position + ((self.pageSize - 1) << 3)
		else:
			nodePosition = position + ((half) << 3)

		cdef u8 state = OccupationState.PAGE
		cdef u64 meta = (self.rootPagePosition << 2) | state
		self.positionStream.position = 0
		setBuffer(&self.positionStream, <char *> &meta, 8)
		self.io.seek(nodePosition)
		self.io.write(&self.positionStream)
		self.rootPagePosition = position
		self.max = self.min + self.width*self.pageSize
		self.maxDepth = self.maxDepth + 1
		self.writeHeader()
		return position
	
	cdef u64 insertNode(self, u64 page, RecordNode node, i32 *depth):
		cdef f128 rangeValue = node.getRangeValue()
		cdef i32 maxDepth = depth[0]
		cdef f128 width = self.width/(1 << ((maxDepth-1)*self.potence))
		cdef i64 normalized = normalizeIndex(self, maxDepth, rangeValue)
		cdef i64 index = calculateLayerIndex(self, maxDepth, normalized, maxDepth-1)
		cdef i64 position = page + (index << 3)
		self.io.seek(position)
		self.io.read(&self.positionStream, 8)
		cdef u64 meta = (<u64*> getBuffer(&self.positionStream, 8))[0]
		cdef u8  state = meta &  3
		cdef u64 child = meta >> 2
		
		if state == OccupationState.NODE:
			self.readNodeKey(child, self.comparingNode)
			child = self.createPage()
			state = OccupationState.PAGE
			self.positionStream.position = 0
			meta = (child << 2) | state
			setBuffer(&self.positionStream, <char *> &meta, 8)
			self.io.seek(position)
			self.io.write(&self.positionStream)
			depth[0] = depth[0] + 1
			child = self.insertNode(child, self.comparingNode, depth)
			child = self.insertNode(child, node, depth)
			return child
		else:
			if node.position < 0: self.appendNode(node)
			state = OccupationState.NODE
			self.positionStream.position = 0
			meta = <u64> node.position
			meta = (meta << 2) | state
			setBuffer(&self.positionStream, <char *> &meta, 8)
			self.io.seek(position)
			self.io.write(&self.positionStream)
			return page
