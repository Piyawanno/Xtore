from xtore.BaseType cimport u8, i32, u64
from xtore.common.Buffer cimport Buffer
from xtore.instance.ScopeIterator cimport ScopeIterator
from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage, OccupationState
from xtore.instance.RecordNode cimport RecordNode

cdef class ScopeBackwardIterator (ScopeIterator):
	def __init__(self, ScopeTreeStorage storage):
		ScopeIterator.__init__(self, storage)

	cdef start(self):
		self.getTail()

	cdef bint getNext(self, RecordNode node):
		if not self.hasNext: return self.hasNext
		self.storage.readNodeKey(self.currentPosition, node)
		self.storage.readNodeValue(node)
		self.hasNext = self.moveBackPage()
		return True
	