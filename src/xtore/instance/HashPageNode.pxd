from xtore.instance.HashNode cimport HashNode
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i64

cdef class HashPageNode(HashNode):
	cdef i64 pagePosition
	cdef i64 itemPosition
	
	cdef readItem(self, Buffer *stream)
	
	cdef writerUpperItem(self, Buffer *stream, i64 lowerPagePosition)
	cdef writeItem(self, Buffer *stream)