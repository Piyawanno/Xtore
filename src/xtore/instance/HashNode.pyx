from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i64

cdef class HashNodeKey:
	pass

cdef class HashNode:
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
