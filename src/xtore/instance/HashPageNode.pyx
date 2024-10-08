from xtore.instance.HashNode cimport HashNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i64

cdef class HashPageNode(HashNode):
	def __init__(self):
		HashNode.__init__(self)
		self.pagePosition = -1
		
	cdef readItem(self, Buffer *stream):
		raise NotImplementedError
	
	cdef writeUpperItem(self, Buffer *stream, i64 lowerPagePosition):
		raise NotImplementedError

	cdef writeItem(self, Buffer *stream):
		raise NotImplementedError
	
	cdef i32 comparePage(self, HashPageNode other):
		raise NotImplementedError
	
	cdef copyPageKey(self, HashPageNode other):
		raise NotImplementedError