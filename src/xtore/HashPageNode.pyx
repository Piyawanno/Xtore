from xtore.HashNode cimport HashNode
from xtore.Buffer cimport Buffer
from xtore.BaseType cimport i64

cdef class HashPageNode(HashNode):
	cdef readItem(self, Buffer *stream):
		raise NotImplementedError
	
	cdef writerUpperItem(self, Buffer *stream, i64 lowerPagePosition):
		raise NotImplementedError

	cdef writeItem(self, Buffer *stream):
		raise NotImplementedError