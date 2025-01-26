from xtore.BaseType cimport u8, i32, u64
from xtore.common.Buffer cimport Buffer
from xtore.instance.ScopeIterator cimport ScopeIterator
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.instance.RecordNode cimport RecordNode

cdef class ScopeSearchResult (ScopeIterator):
	def __init__(self, ScopeTreeStorage storage):
		ScopeIterator.__init__(self, storage)

	cdef start(self):
		pass

	cdef bint getNext(self, RecordNode node):
		if not self.hasNext: return self.hasNext
		self.storage.readNodeKey(self.currentPosition, node)
		self.storage.readNodeValue(node)
		# print(700, self.currentPage, self.endPage, self.currentIndex, self.endIndex)
		if self.currentPage == self.endPage and self.currentIndex == self.endIndex:
			self.hasNext = False
			return True
		self.hasNext = self.moveNextPage()
		return True
	