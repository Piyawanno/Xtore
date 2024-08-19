from xtore.HashNode cimport HashNode
from xtore.Buffer cimport Buffer
from xtore.BaseType cimport i16, i64, u64

cdef class People (HashNode):
	cdef i64 hash(self):
		raise NotImplementedError

	cdef bint isEqual(self, HashNode other):
		raise NotImplementedError

	cdef readKey(self, i16 version, Buffer *stream):
		raise NotImplementedError

	cdef readValue(self, i16 version, Buffer *stream):
		raise NotImplementedError

	cdef write(self, Buffer *stream):
		raise NotImplementedError