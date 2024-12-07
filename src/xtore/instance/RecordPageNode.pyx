from xtore.instance.RecordNode cimport RecordNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i64

cdef class RecordPageNode(RecordNode):
	def __init__(self):
		RecordNode.__init__(self)
		self.pagePosition = -1
		
	cdef readItem(self, Buffer *stream):
		raise NotImplementedError
	
	cdef writeUpperItem(self, Buffer *stream, i64 lowerPagePosition):
		raise NotImplementedError

	cdef writeItem(self, Buffer *stream):
		raise NotImplementedError
	
	cdef i32 comparePage(self, RecordPageNode other):
		raise NotImplementedError
	
	cdef copyPageKey(self, RecordPageNode other):
		raise NotImplementedError