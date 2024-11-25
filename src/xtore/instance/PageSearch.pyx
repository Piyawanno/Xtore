from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage, LINKED_PAGE_HEADER_SIZE
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.common.TimeUtil cimport getMicroTime
from xtore.BaseType cimport i32, i64, f64
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

cdef i32 PAGE_CHUNK_SIZE = 2048
cdef i32 BUFFER_SIZE = 256

cdef class PageSearch:
	def __init__(self, Page page):
		self.page = page

		self.topLayerSize = PAGE_CHUNK_SIZE
		self.topLayerCount = 0
		self.topLayer = <TopLayerPage *> malloc(self.topLayerSize*sizeof(TopLayerPage))
		self.topLayerBufferCount = 0
		self.topLayerBuffer = <char **> malloc(PAGE_CHUNK_SIZE*8)
		self.setTopLayerBuffer(0)

		self.positionSize = <i32> ((self.page.pageSize-self.page.headerSize)/self.page.itemSize)
		self.position = <i32 *> malloc(self.positionSize*4)

		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.lastTopLayerRead = -1
		self.currentStoragePostition = -1
		
		cdef int i
		cdef int j = self.page.headerSize
		for i in range(self.positionSize):
			self.position[i] = j
			j += self.page.itemSize

	def __dealloc__(self):
		if self.topLayerSize > 0: free(self.topLayer)
		self.topLayerSize = 0
		if self.positionSize > 0: free(self.position)
		for i in range(self.topLayerBufferCount):
			free(self.topLayerBuffer[i])
		free(self.topLayerBuffer)
		self.positionSize = 0
		releaseBuffer(&self.stream)

	cdef setPage(self, Page page):
		if self.page.pageSize == page.pageSize and self.page.itemSize == page.itemSize:
			self.page = page
			return
		cdef int n = <int> ((self.page.pageSize-self.page.headerSize)/self.page.itemSize)
		cdef int i
		cdef int j = self.page.headerSize
		self.page = page
		if n > self.positionSize:
			self.positionSize = n
			free(self.position)
			self.position = <i32 *> malloc(self.positionSize*4)
			for i in range(n):
				self.position[i] = j
				j += self.page.itemSize
	
	cdef readPosition(self, i64 storagePosition, f64 lastUpdate):
		if self.currentStoragePostition == storagePosition and lastUpdate <= self.lastTopLayerRead: return
		self.currentStoragePostition = storagePosition
		cdef LinkedPage page = <LinkedPage> self.page
		cdef i64 previous = page.previous
		cdef i64 root = page.position
		while previous > 0:
			root = previous
			page.readHeader(previous)
			previous = page.previous
		
		cdef i64 next = root
		cdef i32 i = 0
		cdef i32 pageSize
		cdef i32 itemsize = self.page.itemSize
		cdef i32 bufferSize
		cdef char *buffer
		cdef TopLayerPage *top
		while next > 0:
			if i >= self.topLayerSize:
				pageSize = self.topLayerSize + PAGE_CHUNK_SIZE
				buffer = <char *> malloc(pageSize*sizeof(TopLayerPage))
				memcpy(buffer, self.topLayer, self.topLayerSize*8)
				free(self.topLayer)
				self.topLayer = <TopLayerPage *> buffer
				self.setTopLayerBuffer(self.topLayerSize)
				self.topLayerSize = pageSize
			page.readHeader(next)
			top = &self.topLayer[i]
			top.position = page.position
			top.next = page.next
			top.previous = page.previous
			top.n = page.n
			page.io.seek(page.position+LINKED_PAGE_HEADER_SIZE)
			page.io.read(&top.head, itemsize)
			page.io.seek(page.position+page.tail-itemsize)
			page.io.read(&top.tail, itemsize)
			# print(666, i, top.position, top.next, top.previous, top.n, (<i32 *> (top.head.buffer+8))[0], (<i32 *> (top.tail.buffer+8))[0])
			i += 1
			next = page.next
		
		page.read(page.position)
		self.topLayerCount = i
		self.lastTopLayerRead = getMicroTime()
	
	cdef setTopLayerBuffer(self, i32 startPosition):
		if self.topLayerBufferCount >= PAGE_CHUNK_SIZE:
			raise ValueError("Top Layer is too large. The design is must be reconsidered.")
		cdef i32 position = 0
		cdef i32 itemSize = self.page.itemSize
		cdef i32 i
		cdef char* buffer = <char *> malloc(PAGE_CHUNK_SIZE*itemSize*2)
		for i in range(PAGE_CHUNK_SIZE):
			initBuffer(&self.topLayer[startPosition+i].head, buffer + position, itemSize)
			position += itemSize
			initBuffer(&self.topLayer[startPosition+i].tail, buffer + position, itemSize)
			position += itemSize
		self.topLayerBuffer[self.topLayerBufferCount] = buffer
		self.topLayerBufferCount += 1

	cdef LinkedPage getPageInRange(self, Buffer *reference):
		cdef bint isFound = False
		cdef i32 index
		if self.topLayerCount == 1: index = 0
		else: index = self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		cdef TopLayerPage top = self.topLayer[index]
		if isFound:
			if isPageChanged(page, top): page.read(top.position)
			return page
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			top = self.topLayer[index]
			if self.isUpperLess(reference, index):
				index = index - 1
				if hasGreater: return None
				hasLess = True
			elif self.isUpperGreater(reference, index):
				index = index + 1
				if hasLess: return None
				hasGreater = True
			else:
				if isPageChanged(page, top): page.read(top.position)
				return page
	
	cdef i32 getGreaterPage(self, Buffer *reference):
		cdef bint isFound = False
		cdef i32 index
		cdef TopLayerPage top
		if self.topLayerCount == 1: index = 0
		else: index = self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			top = self.topLayer[index]
			if self.isUpperLess(reference, index):
				hasLess = True
				index = index - 1
				if top.previous < 0 or index < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return 0
				if hasGreater:
					top = self.topLayer[index]
					if isPageChanged(self.page, top): self.page.read(top.position)
					return top.n
			elif self.isUpperGreater(reference, index):
				index = index + 1
				if hasLess or top.next < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return top.n
				hasGreater = True
			else:
				if isPageChanged(self.page, top): self.page.read(top.position)
				return self.getGreater(reference)

	cdef i32 getLessPage(self, Buffer *reference):
		cdef bint isFound = False
		cdef i32 index
		cdef TopLayerPage top
		if self.topLayerCount == 1: index = 0
		else: index = self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			top = self.topLayer[index]
			if self.isUpperLess(reference, index):
				hasLess = True
				index = index - 1
				# NOTE All data are greater than reference.
				if top.previous < 0 or index < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return -1
				# NOTE The last item of the previous page is less than reference
				if hasGreater:
					top = self.topLayer[index]
					if isPageChanged(self.page, top): self.page.read(top.position)
					return top.n - 1
				hasLess = True
			elif self.isUpperGreater(reference, index):
				index = index + 1
				# NOTE 1. The last item is less than reference
				# NOTE 2. All data are less than reference.
				if hasLess or top.next < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return page.n - 1
				hasGreater = True
			else:
				if isPageChanged(self.page, top): self.page.read(top.position)
				return self.getLess(reference)

	cdef i32 getGreaterEqualPage(self, Buffer *reference):
		cdef bint isFound = False
		cdef i32 index
		cdef TopLayerPage top
		if self.topLayerCount == 1: index = 0
		else: index = self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		if isFound: return index
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			top = self.topLayer[index]
			if self.isUpperLess(reference, index):
				hasLess = True
				index = index - 1
				if top.previous < 0 or index < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return 0
				if hasGreater:
					top = self.topLayer[index]
					if isPageChanged(self.page, top): self.page.read(top.position)
					return top.n
			elif self.isUpperGreater(reference, index):
				index = index + 1
				if hasLess or top.next < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return top.n
				hasGreater = True
			else:
				if isPageChanged(self.page, top): self.page.read(top.position)
				return self.getGreaterEqual(reference)

	cdef i32 getLessEqualPage(self, Buffer *reference):
		cdef bint isFound = False
		cdef i32 index
		cdef TopLayerPage top
		if self.topLayerCount == 1: index = 0
		else: index = self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		if isFound: return index
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			top = self.topLayer[index]
			if self.isUpperLess(reference, index):
				hasLess = True
				index = index - 1
				# NOTE All data are greater than reference.
				if top.previous < 0 or index < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return -1
				# NOTE The last item of the previous page is less than reference
				if hasGreater:
					top = self.topLayer[index]
					if isPageChanged(self.page, top): self.page.read(top.position)
					return top.n - 1
				hasLess = True
			elif self.isUpperGreater(reference, index):
				index = index + 1
				# NOTE 1. The last item is less than reference
				# NOTE 2. All data are less than reference.
				if hasLess or top.next < 0:
					if isPageChanged(self.page, top): self.page.read(top.position)
					return page.n - 1
				hasGreater = True
			else:
				if isPageChanged(self.page, top): self.page.read(top.position)
				return self.getLessEqual(reference)

	cdef bint isUpperInRange(self, Buffer *reference, i32 index):
		cdef i32 head = self.compare(reference, &self.topLayer[index].head)
		if head < 0: return False
		cdef i32 tail = self.compare(reference, &self.topLayer[index].tail)
		if tail > 0: return False
		return True
	
	cdef bint isUpperLess(self, Buffer *reference, i32 index):
		self.page.stream.position = self.page.headerSize
		cdef i32 head = self.compare(reference, &self.topLayer[index].head)
		return head < 0
	
	cdef bint isUpperGreater(self, Buffer *reference, i32 index):
		cdef i32 tail = self.compare(reference, &self.topLayer[index].tail)
		return tail > 0
	
	cdef bint isInRange(self, Buffer *reference):
		if self.page.tail <= self.page.headerSize: return False
		self.page.stream.position = self.page.headerSize
		cdef i32 head = self.compare(reference, &self.page.stream)
		if head < 0: return False
		self.page.stream.position = self.page.tail - self.page.itemSize
		cdef i32 tail = self.compare(reference, &self.page.stream)
		if tail > 0: return False
		return True
	
	cdef bint isLess(self, Buffer *reference):
		self.page.stream.position = self.page.headerSize
		cdef i32 head = self.compare(reference, &self.page.stream)
		return head < 0
	
	cdef bint isGreater(self, Buffer *reference):
		self.page.stream.position = self.page.tail - self.page.itemSize
		cdef i32 tail = self.compare(reference, &self.page.stream)
		return tail > 0

	cdef i32 getEqual(self, Buffer *reference):
		if not self.isInRange(reference): return -1
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound: return position
		else: return -1

	cdef i32 getGreater(self, Buffer *reference):
		if self.isGreater(reference): return -1
		if self.isLess(reference): return 0
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound:
			if position < self.page.n-1: return position+1
			else: return -1
		cdef int compared
		while position < self.page.n:
			self.page.stream.position = self.position[position]
			compared = self.compare(reference, &self.page.stream)
			if compared < 1: return position
			position += 1

	cdef i32 getLess(self, Buffer *reference):
		if self.isGreater(reference): return self.page.n - 1
		if self.isLess(reference): return -1
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound:
			if position > 1: return position-1
			else: return -1
		cdef int compared
		while position >= 0:
			self.page.stream.position = self.position[position]
			compared = self.compare(reference, &self.page.stream)
			if compared > 0: return position
			position = position - 1

	cdef i32 getGreaterEqual(self, Buffer *reference):
		if self.isGreater(reference): return -1
		if self.isLess(reference): return 0
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound: return position
		cdef int compared
		while position < self.page.n:
			self.page.stream.position = self.position[position]
			compared = self.compare(reference, &self.page.stream)
			if compared <= 0: return position
			position += 1

	cdef i32 getLessEqual(self, Buffer *reference):
		if self.isGreater(reference): return self.page.n - 1
		if self.isLess(reference): return -1
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound: return position
		cdef int compared
		while position >= 0:
			self.page.stream.position = self.position[position]
			compared = self.compare(reference, &self.page.stream)
			if compared >= 0: return position
			position = position - 1
	
	cdef i32 search(self, Buffer *reference, bint *isFound):
		isFound[0] = False
		cdef i32 n = self.page.n
		cdef i32 low = 0
		cdef i32 high = n - 1
		cdef i32 i = 0
		cdef i32 compared
		while low <= high:
			i = (high + low) // 2
			self.page.stream.position = self.position[i]
			compared = self.compare(reference, &self.page.stream)
			if compared > 0 :
				low = i + 1
			elif compared < 0 :
				high = i - 1
			else:
				isFound[0] = True
				return i
		return i
	
	cdef i32 searchPage(self, Buffer *reference, bint *isFound):
		isFound[0] = False
		cdef i32 n = self.topLayerCount
		cdef i32 low = 0
		cdef i32 high = n - 1
		cdef i32 i = 0
		cdef i32 compared
		cdef i64 position
		while low <= high:
			i = (high + low) // 2
			position = self.topLayer[i].position
			compared = self.compare(reference, &self.topLayer[i].head)
			if compared > 0 :
				low = i + 1
			elif compared < 0 :
				high = i - 1
			else:
				isFound[0] = True
				return i
		return i