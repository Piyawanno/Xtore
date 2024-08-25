from xtore.instance.Page cimport Page
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer
from xtore.BaseType cimport i32, i64
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy

cdef i32 PAGE_CHUNK_SIZE = 2048
cdef i32 BUFFER_SIZE = 256

cdef class PageSearch:
	def __init__(self, Page page):
		self.page = page

		self.pagePositionSize = PAGE_CHUNK_SIZE
		self.pagePosition = <i64 *> malloc(self.pagePositionSize*8)

		self.positionSize = <i32> ((self.page.pageSize-self.page.headerSize)/self.page.itemSize)
		self.position = <i32 *> malloc(self.positionSize*4)

		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		
		cdef int i
		cdef int j = self.page.headerSize
		for i in range(self.positionSize):
			self.position[i] = j
			j += self.page.itemSize

	def __dealloc__(self):
		if self.pagePositionSize > 0: free(self.pagePosition)
		self.pagePositionSize = 0
		if self.positionSize > 0: free(self.position)
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
	
	cdef readPosition(self):
		cdef LinkedPage page = <LinkedPage> self.page
		cdef i64 previous = page.previous
		cdef i64 root = page.position
		while previous > 0:
			root = previous
			page.io.seek(previous+8)
			page.io.read(&self.stream, 8)
			previous = (<i64 *> self.stream.buffer)[0]
		
		cdef i64 next = root
		cdef i32 i = 0
		cdef i32 pageSize
		cdef i32 bufferSize
		cdef char *buffer
		while next > 0:
			if i >= self.pagePositionSize:
				pageSize = self.pagePositionSize + PAGE_CHUNK_SIZE
				buffer = <char *> malloc(pageSize*8)
				memcpy(buffer, self.pagePosition, self.pagePositionSize*8)
				free(self.pagePosition)
				self.pagePosition = <i64 *> buffer
				self.pagePositionSize = pageSize
			self.pagePosition[i] = next
			i += 1
			page.io.seek(next)
			page.io.read(&self.stream, 8)
			next = (<i64 *> self.stream.buffer)[0]
		self.pagePositionCount = i
		

	cdef LinkedPage getPageInRange(self, Buffer *reference):
		cdef bint isFound = False
		self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		if isFound: return page
		cdef i64 neighbor
		while True:
			if self.isLess(reference):
				neighbor = page.previous
			elif self.isGreater(reference):
				neighbor = page.next
			else:
				return page
			if neighbor < 0: return None
			page.read(neighbor)
	
	cdef i32 getGreaterPage(self, Buffer *reference):
		cdef bint isFound = False
		self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			if self.isLess(reference):
				# NOTE The first item is greater than reference
				if hasGreater: return 0
				if page.previous > 0: page.read(page.previous)
				# NOTE All data are greater than reference.
				else: return 0
				hasLess = True
			elif self.isGreater(reference):
				if page.next > 0: page.read(page.next)
				# NOTE All data are less than reference.
				elif not hasLess: return -1
				# NOTE The first item of the next page is greater than reference
				if hasLess: return 0
				hasGreater = True
			else:
				return self.getGreater(reference)

	cdef i32 getLessPage(self, Buffer *reference):
		cdef bint isFound = False
		self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			if self.isLess(reference):
				if page.previous > 0: page.read(page.previous)
				# NOTE All data are greater than reference.
				elif not hasGreater: return -1
				# NOTE The last item of the previous page is less than reference
				if hasGreater: return page.n - 1
				hasLess = True
			elif self.isGreater(reference):
				# NOTE The last item is less than reference
				if hasLess: return page.n - 1
				if page.next > 0: page.read(page.next)
				# NOTE All data are less than reference.
				else: return page.n - 1
				hasGreater = True
			else:
				return self.getLess(reference)

	cdef i32 getGreaterEqualPage(self, Buffer *reference):
		cdef bint isFound = False
		cdef index = self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		if isFound: return 0
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			if self.isLess(reference):
				# NOTE The first item is greater than reference
				if hasGreater: return 0
				if page.previous > 0: page.read(page.previous)
				# NOTE All data are greater than reference.
				else: return 0
				hasLess = True
			elif self.isGreater(reference):
				if page.next > 0: page.read(page.next)
				# NOTE All data are less than reference.
				elif not hasLess: return -1
				# NOTE The first item of the next page is greater than reference
				if hasLess: return 0
				hasGreater = True
			else:
				return self.getGreaterEqual(reference)

	cdef i32 getLessEqualPage(self, Buffer *reference):
		cdef bint isFound = False
		self.searchPage(reference, &isFound)
		cdef LinkedPage page = <LinkedPage> self.page
		if isFound: return 0
		cdef bint hasGreater = False
		cdef bint hasLess = False
		while True:
			if self.isLess(reference):
				if page.previous > 0: page.read(page.previous)
				# NOTE All data are greater than reference.
				elif not hasGreater: return -1
				# NOTE The last item of the previous page is less than reference
				if hasGreater: return page.n - 1
				hasLess = True
			elif self.isGreater(reference):
				# NOTE The last item is less than reference
				if hasLess: return page.n - 1
				if page.next > 0: page.read(page.next)
				# NOTE All data are less than reference.
				else: return page.n - 1
				hasGreater = True
			else:
				return self.getLessEqual(reference)

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
		if not self.isInRange(reference): return -1
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound:
			if position < self.page.n-1: return position+1
			else: return -1
		cdef int compared
		while True:
			self.page.stream.position = self.position[position]
			compared = self.compare(reference, &self.page.stream)
			if compared < 1: return position
			position += 1

	cdef i32 getLess(self, Buffer *reference):
		if not self.isInRange(reference): return -1
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound:
			if position > 1: return position-1
			else: return -1
		cdef int compared
		while True:
			self.page.stream.position = self.position[position]
			compared = self.compare(reference, &self.page.stream)
			if compared > 0: return position
			position = position - 1

	cdef i32 getGreaterEqual(self, Buffer *reference):
		if not self.isInRange(reference): return -1
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound: return position
		cdef int compared
		while True:
			self.page.stream.position = self.position[position]
			compared = self.compare(reference, &self.page.stream)
			if compared <= 0: return position
			position += 1

	cdef i32 getLessEqual(self, Buffer *reference):
		if not self.isInRange(reference): return -1
		cdef bint isFound = False
		cdef i32 position = self.search(reference, &isFound)
		if isFound: return position
		cdef int compared
		while True:
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
		cdef i32 n = self.pagePositionCount
		cdef i32 low = 0
		cdef i32 high = n - 1
		cdef i32 i = 0
		cdef i32 compared
		cdef i64 position
		while low <= high:
			i = (high + low) // 2
			position = self.pagePosition[i]
			self.page.read(position)
			self.page.stream.position = self.position[0]
			compared = self.compare(reference, &self.page.stream)
			if compared > 0 :
				low = i + 1
			elif compared < 0 :
				high = i - 1
			else:
				isFound[0] = True
				return i
		return i