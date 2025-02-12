from xtore.BaseType cimport u8, i32, i64, u64, f128
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, getBuffer, initBuffer, releaseBuffer
from xtore.instance.ScopeTreeStorage cimport (
	ScopeTreeStorage,
	OccupationState,
	normalizeIndex,
	calculateLayerIndex
)
from xtore.instance.ScopeSearchResult cimport ScopeSearchResult
from xtore.instance.RecordNode cimport RecordNode

from libc.stdlib cimport malloc

cdef str getPositionString(NodePosition position):
	return f'<NodePosition page={position.page} index={position.index} depth={position.depth} position={position.position}>'

cdef class ScopeSearch:
	def __init__(self, ScopeTreeStorage storage):
		self.storage = storage
		self.io = storage.io
		self.stored = storage.createNode()
		initBuffer(&self.positionStream, <char *> malloc(16), 16)
	
	def __dealloc__(self):
		releaseBuffer(&self.positionStream)
	
	cdef ScopeSearchResult getGreater(self, RecordNode reference):
		cdef ScopeSearchResult result = ScopeSearchResult(self.storage)
		cdef NodePosition position
		cdef bint isFound
		self.depth = self.storage.getDepth()
		cdef f128 key = reference.getRangeValue()
		if key > self.storage.min:
			result.getTail()
			result.endPage = result.currentPage
			result.endIndex = result.currentIndex
			isFound = self.search(reference, result, &position)
			result.currentStream = position.stream
			result.currentPage = position.page
			result.currentPosition = position.position
			result.currentIndex = position.index
			result.currentDepth = position.depth
			result.hasNext = result.moveNextPage()
		else:
			result.getHead()
		return result

	cdef ScopeSearchResult getGreaterEqual(self, RecordNode reference):
		cdef ScopeSearchResult result = ScopeSearchResult(self.storage)
		cdef NodePosition position
		cdef bint isFound
		self.depth = self.storage.getDepth()
		cdef f128 key = reference.getRangeValue()
		if key > self.storage.min:
			result.getTail()
			result.endPage = result.currentPage
			result.endIndex = result.currentIndex
			isFound = self.search(reference, result, &position)
			result.currentStream = position.stream
			result.currentPage = position.page
			result.currentPosition = position.position
			result.currentIndex = position.index
			result.currentDepth = position.depth
			if not isFound: result.moveNextPage()
		else:
			result.getHead()
		return result

	cdef ScopeSearchResult getLess(self, RecordNode reference):
		cdef ScopeSearchResult result = ScopeSearchResult(self.storage)
		cdef NodePosition position
		cdef bint isFound
		self.depth = self.storage.getDepth()
		cdef f128 key = reference.getRangeValue()
		if key < self.storage.max:
			isFound = self.search(reference, result, &position)
			result.currentStream = position.stream
			result.currentPage = position.page
			result.currentPosition = position.position
			result.currentIndex = position.index
			result.currentDepth = position.depth
			result.moveBackPage()
			result.endPage = result.currentPage
			result.endIndex = result.currentIndex
		else:
			result.endIndex = -1
		result.getHead()
		return result

	cdef ScopeSearchResult getLessEqual(self, RecordNode reference):
		cdef ScopeSearchResult result = ScopeSearchResult(self.storage)
		cdef NodePosition position
		cdef bint isFound
		self.depth = self.storage.getDepth()
		cdef f128 key = reference.getRangeValue()
		if key < self.storage.max:
			isFound = self.search(reference, result, &position)
			result.currentStream = position.stream
			result.currentPage = position.page
			result.currentPosition = position.position
			result.currentIndex = position.index
			result.currentDepth = position.depth
			if not isFound: result.moveBackPage()
			result.endPage = result.currentPage
			result.endIndex = result.currentIndex
		else:
			result.endIndex = -1
		result.getHead()
		return result

	cdef ScopeSearchResult getRange(
		self,
		RecordNode start,
		RecordNode end,
		bint isLowerIncluded,
		bint isUpperIncluded
	):
		cdef ScopeSearchResult result = ScopeSearchResult(self.storage)
		cdef NodePosition position
		self.depth = self.storage.getDepth()
		cdef bint isFound
		cdef f128 key = end.getRangeValue()
		if key < self.storage.max:
			isFound = self.search(end, result, &position)
			result.currentStream = position.stream
			result.currentPage = position.page
			result.currentPosition = position.position
			result.currentIndex = position.index
			result.currentDepth = position.depth
			if not isUpperIncluded or not isFound: result.moveBackPage()
			result.endPage = result.currentPage
			result.endIndex = result.currentIndex
		else:
			result.endIndex = -1

		key = start.getRangeValue()
		if key > self.storage.min:
			isFound = self.search(start, result, &position)
			result.currentStream = position.stream
			result.currentPage = position.page
			result.currentPosition = position.position
			result.currentIndex = position.index
			result.currentDepth = position.depth
			if not isLowerIncluded or not isFound: result.hasNext = result.moveNextPage()
			else: result.hasNext = True
		else:
			result.getHead()
		return result
	
	cdef bint search(self, RecordNode reference, ScopeSearchResult result, NodePosition *position):
		cdef i32 maxDepth = self.depth
		cdef f128 key = reference.getRangeValue()
		cdef i64 normalized = normalizeIndex(self.storage, maxDepth, key)
		cdef i64 current = self.storage.rootPagePosition
		cdef i64 index
		cdef u64 child
		cdef u64 meta
		cdef u8 state
		cdef RecordNode stored
		cdef Buffer *stream
		
		for i in range(maxDepth):
			index = calculateLayerIndex(self.storage, maxDepth, normalized, i)
			stream = &result.streamList[i]
			result.index[i] = index
			self.io.seek(current)
			self.io.read(stream, result.pageBufferSize)
			meta = (<u64*> (stream.buffer+(index << 3)))[0]
			state = meta &  3
			child = meta >> 2
			if state == OccupationState.PAGE:
				current = child
			else:
				position.stream = stream
				position.page = current
				position.index = index
				position.depth = i
				position.position = child
				if state == OccupationState.NODE:
					stored = self.storage.readNodeKey(child, self.stored)
					return reference.compare(stored) == 0
				else:
					return False
		